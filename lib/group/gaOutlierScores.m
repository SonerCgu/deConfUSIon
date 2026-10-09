function [flag,z,notes,report] = gaOutlierScores(x,subjects,method,threshold)
% Exploratory screening within Group x Condition, never pooled treatments.
x=double(x(:)); flag=false(size(x)); z=nan(size(x)); notes={};
report=struct();
for field={'mean','sampleSD','median','MAD','Q1','Q3','IQR','lowerFence','upperFence','score','stratumN'}
    report.(field{1})=nan(size(x));
end
report.method=method;report.threshold=threshold;
assert(size(subjects,1)==numel(x),'GroupAnalysis:Outliers','Metrics and rows must match.');
if strcmpi(method,'None'), return; end
assert(isscalar(threshold)&&isfinite(threshold)&&threshold>0, ...
    'GroupAnalysis:Outliers','Outlier threshold must be finite and positive.');
assert(any(strcmpi(method,{'MAD robust z-score','IQR rule','SD z-score (exploratory)'})), ...
    'GroupAnalysis:Outliers','Unknown outlier method.');
groups=cellfun(@(v)lower(strtrim(char(v))),subjects(:,3),'UniformOutput',false);
conds=cellfun(@(v)lower(strtrim(char(v))),subjects(:,4),'UniformOutput',false);
done=false(size(x));
for i=1:numel(x)
    if done(i), continue; end
    stratum=strcmp(groups,groups{i}) & strcmp(conds,conds{i}); done(stratum)=true;
    idx=find(stratum & isfinite(x)); v=x(idx);
    label=sprintf('%s / %s',groups{i},conds{i});
    if numel(v)<4
        notes{end+1,1}=sprintf('%s: insufficient finite rows (n=%d; need >=4).',label,numel(v)); %#ok<AGROW>
        continue;
    end
    ids=cellfun(@(v)lower(strtrim(char(v))),subjects(idx,2),'UniformOutput',false);
    if any(cellfun(@isempty,ids))
        notes{end+1,1}=sprintf('%s: missing Animal IDs; identify independent animals before screening.',label); %#ok<AGROW>
        continue;
    end
    if numel(unique(ids))<numel(ids)
        notes{end+1,1}=sprintf('%s: repeated subject IDs; aggregate replicates before screening.',label); %#ok<AGROW>
        continue;
    end
    med=median(v); madv=median(abs(v-med));
    q=prctile(v,[25 75]); spread=q(2)-q(1);mu=mean(v);sd=std(v,0);
    report.mean(idx)=mu;report.sampleSD(idx)=sd;report.median(idx)=med;
    report.MAD(idx)=madv;report.Q1(idx)=q(1);report.Q3(idx)=q(2);report.IQR(idx)=spread;
    report.stratumN(idx)=numel(v);
    if madv>0, z(idx)=0.6745*(v-med)/madv; end
    if strcmpi(method,'MAD robust z-score')
        if madv==0
            notes{end+1,1}=sprintf('%s: MAD is zero; modified Z is undefined, no rows flagged.',label); %#ok<AGROW>
            continue;
        end
        report.score(idx)=z(idx);
        report.lowerFence(idx)=med-threshold*madv/.6745;
        report.upperFence(idx)=med+threshold*madv/.6745;
        flag(idx)=abs(z(idx))>threshold;
    elseif strcmpi(method,'IQR rule')
        if spread==0
            notes{end+1,1}=sprintf('%s: IQR is zero; no automatic flags.',label); %#ok<AGROW>
            continue;
        end
        report.score(idx)=(v-med)/spread;
        report.lowerFence(idx)=q(1)-threshold*spread;
        report.upperFence(idx)=q(2)+threshold*spread;
        flag(idx)=v<q(1)-threshold*spread | v>q(2)+threshold*spread;
    else
        if sd==0
            notes{end+1,1}=sprintf('%s: sample SD is zero; no automatic flags.',label); %#ok<AGROW>
            continue;
        end
        report.score(idx)=(v-mu)/sd;
        report.lowerFence(idx)=mu-threshold*sd;report.upperFence(idx)=mu+threshold*sd;
        flag(idx)=abs(report.score(idx))>threshold;
        maxZ=(numel(v)-1)/sqrt(numel(v));
        if threshold>=maxZ
            notes{end+1,1}=sprintf('%s: n=%d bounds |SD z| <= %.3g; a %.3g-SD rule cannot flag any row. MAD/IQR are more robust screens.', ...
                label,numel(v),maxZ,threshold); %#ok<AGROW>
        end
    end
end
notes{end+1,1}='Exploratory flags within Group x Condition; not significance tests or evidence of bad data. Use prespecified/QC exclusion criteria.';
end
