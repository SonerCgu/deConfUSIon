function result=gaTitrationComparisons(D,S)
% Animal-level pairwise titration tests; direction is always left minus right.
% D.categories: key,label,doseM. D.categoryPoints: animalID,animalKey,
% categoryKey,value. Points must already be unique animal/category means.
% S.titrationComparisons: left,right,test,tail,show. Only selected rows form
% the multiplicity family; unavailable tests do not shrink that family.
% CI are nominal, pointwise intervals, not simultaneous family intervals.
if nargin<2,S=struct();end
alpha=readField(S,'alpha',.05);
if ~isnumeric(alpha)||~isscalar(alpha)||~isfinite(alpha)||alpha<=0||alpha>=1
    error('GroupAnalysis:TitrationAlpha','Alpha must be between 0 and 1.');
end
correction=char(readField(S,'titrationCorrection','None'));
options={'Holm','Bonferroni','None'};hit=find(strcmpi(correction,options),1);
if isempty(hit),error('GroupAnalysis:TitrationCorrection','Choose Holm, Bonferroni or None.');end
correction=options{hit};
selected=readField(S,'titrationComparisons',struct([]));
if ~isstruct(selected),error('GroupAnalysis:TitrationComparisons','Comparisons must be a structure array.');end
keep=false(size(selected));
for i=1:numel(selected),keep(i)=logicalSetting(readField(selected(i),'show',false));end
selected=selected(keep);
comparisons=repmat(emptyComparison(alpha),size(selected));
for i=1:numel(selected),comparisons(i)=calculateOne(D,selected(i),alpha);end
raw=[comparisons.pRaw];adjusted=adjustP(raw,correction,numel(selected));
for i=1:numel(comparisons)
    comparisons(i).pAdjusted=adjusted(i);
    comparisons(i).significant=isfinite(adjusted(i))&&adjusted(i)<alpha;
end
result=struct('comparisons',comparisons,'correction',correction, ...
    'familySize',numel(selected),'nComputed',sum(isfinite(raw)),'alpha',alpha, ...
    'confidenceLevel',1-alpha,'effectDirection','Mean(left) minus mean(right)', ...
    'ciNote','Nominal pointwise confidence intervals; not adjusted for multiple comparisons.', ...
    'familyNote','All selected comparisons define the correction family, including unavailable tests.');
end

function out=calculateOne(D,request,alpha)
out=emptyComparison(alpha);
out.leftKey=char(readField(request,'left',''));out.rightKey=char(readField(request,'right',''));
out.leftLabel=out.leftKey;out.rightLabel=out.rightKey;
out.test=char(readField(request,'test','Student t-test'));
out.tail=lower(char(readField(request,'tail','right')));
if ~isfield(D,'categories')||~isstruct(D.categories)||~isfield(D.categories,'key')||~isfield(D.categories,'label')
    out.status='missing category';out.warning='The plotted categories are unavailable.';return;
end
left=find(strcmp({D.categories.key},out.leftKey));right=find(strcmp({D.categories.key},out.rightKey));
if numel(left)~=1||numel(right)~=1
    out.status='missing category';out.warning='Each selected endpoint must identify exactly one plotted category.';return;
end
out.leftLabel=char(D.categories(left).label);out.rightLabel=char(D.categories(right).label);
if strcmp(out.leftKey,out.rightKey)
    out.status='same category';out.warning='Select two different categories.';return;
end
tests={'Paired t-test','Welch t-test','Student t-test'};hit=find(strcmpi(out.test,tests),1);
if isempty(hit),out.status='invalid test';out.warning='Choose Paired t-test, Welch t-test or Student t-test.';return;end
out.test=tests{hit};
if ~any(strcmp(out.tail,{'both','right','left'}))
    out.status='invalid tail';out.warning='Choose both, right or left for the test tail.';return;
end
symbol='~=';if strcmp(out.tail,'right'),symbol='>';elseif strcmp(out.tail,'left'),symbol='<';end
out.alternative=[out.leftLabel ' ' symbol ' ' out.rightLabel];
L=categoryData(D,out.leftKey);R=categoryData(D,out.rightKey);
out.nAvailableLeft=numel(L.values);out.nAvailableRight=numel(R.values);
out.nLeft=out.nAvailableLeft;out.nRight=out.nAvailableRight;
out.leftAnimalIDs=L.ids;out.rightAnimalIDs=R.ids;
out.valuesLeft=L.values;out.valuesRight=R.values;
out.nonfiniteLeftIDs=L.nonfiniteIDs;out.nonfiniteRightIDs=R.nonfiniteIDs;
out.duplicateLeftIDs=L.duplicateIDs;out.duplicateRightIDs=R.duplicateIDs;
if ~isempty(L.duplicateIDs)||~isempty(R.duplicateIDs)
    out.status='duplicate animal';out.warning='Duplicate animal/category points must be resolved before testing; they were not averaged.';return;
end
if L.missingIdentity||R.missingIdentity
    out.status='missing animal identity';out.warning='Animal keys are required to verify independence and pairing.';return;
end
if L.invalidValue||R.invalidValue
    out.status='invalid value';out.warning='Each animal point must have one real numeric scalar response.';return;
end
if ~isempty(L.nonfiniteIDs)||~isempty(R.nonfiniteIDs)
    out.warning='Nonfinite animal responses were omitted.';
end
[shared,rightIndex]=ismember(L.keys,R.keys);
out.overlappingIDs=L.ids(shared);
if strcmp(out.test,'Paired t-test')
    out.unmatchedLeftIDs=L.ids(~shared);out.unmatchedRightIDs=R.ids(~ismember(R.keys,L.keys));
    out.unmatchedIDs=[out.unmatchedLeftIDs;out.unmatchedRightIDs];
    out.leftAnimalIDs=L.ids(shared);out.rightAnimalIDs=R.ids(rightIndex(shared));
    out.valuesLeft=L.values(shared);out.valuesRight=R.values(rightIndex(shared));
    out.pairedAnimalIDs=out.leftAnimalIDs;out.nPairs=numel(out.valuesLeft);
    out.nLeft=out.nPairs;out.nRight=out.nPairs;
    if ~isempty(out.unmatchedIDs),out.warning=addWarning(out.warning,'Unmatched animals were omitted from the paired test.');end
elseif any(shared)
    % Honor the explicitly selected test instead of silently replacing it or
    % suppressing its p-value. Shared IDs remain visible in the diagnostics.
    out.warning=addWarning(out.warning, ...
        ['Shared Animal IDs are present. This selected independent-samples test assumes independent observations; ' ...
        'use a paired test when these IDs denote repeated measurements.']);
end
a=out.valuesLeft;b=out.valuesRight;
if ~isempty(a),out.meanLeft=mean(a);end
if ~isempty(b),out.meanRight=mean(b);end
out.effect=out.meanLeft-out.meanRight;
if out.nLeft<2||out.nRight<2
    out.status='insufficient samples';
    if strcmp(out.test,'Paired t-test'),message='At least two matched finite animal pairs are required.';
    else,message='At least two finite independent animals per category are required.';end
    out.warning=addWarning(out.warning,message);return;
end
if strcmp(out.test,'Paired t-test')
    differences=a-b;out.effect=mean(differences);out.df=numel(differences)-1;
    se=std(differences,0)/sqrt(numel(differences));
elseif strcmp(out.test,'Student t-test')
    out.df=numel(a)+numel(b)-2;
    pooled=((numel(a)-1)*var(a,0)+(numel(b)-1)*var(b,0))/out.df;
    se=sqrt(pooled*(1/numel(a)+1/numel(b)));
else
    terms=[var(a,0)/numel(a) var(b,0)/numel(b)];total=sum(terms);
    se=sqrt(total);
    if total>0
        weights=terms/total;out.df=1/(weights(1)^2/(numel(a)-1)+weights(2)^2/(numel(b)-1));
    end
end
out.standardError=se;
if ~isfinite(se)||~isfinite(out.df)||out.df<=0||(se==0&&out.effect==0)
    out.status='undefined variance';out.warning=addWarning(out.warning,'The sample variance does not define this t-test.');return;
end
out.t=out.effect/se;
if strcmp(out.tail,'right'),out.pRaw=tCDF(-out.t,out.df);
elseif strcmp(out.tail,'left'),out.pRaw=tCDF(out.t,out.df);
else,out.pRaw=min(1,2*tCDF(-abs(out.t),out.df));end
if strcmp(out.tail,'both')
    critical=tQuantile(1-alpha/2,out.df);out.ci=out.effect+[-1 1]*critical*se;
elseif strcmp(out.tail,'right')
    critical=tQuantile(1-alpha,out.df);out.ci=[out.effect-critical*se Inf];
else
    critical=tQuantile(1-alpha,out.df);out.ci=[-Inf out.effect+critical*se];
end
if se==0,out.warning=addWarning(out.warning,'Zero sample variance gives a degenerate t-test; check measurement precision.');end
if isfinite(out.pRaw),out.status='ok';
else,out.status='undefined variance';out.warning=addWarning(out.warning,'The p-value is undefined.');end
end

function data=categoryData(D,key)
data=struct('ids',{{}},'keys',{{}},'values',zeros(0,1),'nonfiniteIDs',{{}}, ...
    'duplicateIDs',{{}},'missingIdentity',false,'invalidValue',false);
if ~isfield(D,'categoryPoints')||isempty(D.categoryPoints),return;end
P=D.categoryPoints;
if ~isstruct(P)||~all(isfield(P,{'categoryKey','animalKey','value'}))
    data.invalidValue=true;return;
end
allKeys={};allIDs={};
for i=1:numel(P)
    if ~strcmp(char(P(i).categoryKey),key),continue;end
    animalKey=lower(strtrim(char(P(i).animalKey)));
    id=char(readField(P(i),'animalID',animalKey));
    if isempty(animalKey),data.missingIdentity=true;continue;end
    allKeys{end+1,1}=animalKey;allIDs{end+1,1}=id; %#ok<AGROW>
    value=P(i).value;
    if ~isnumeric(value)||~isscalar(value)||~isreal(value),data.invalidValue=true;continue;end
    if ~isfinite(value),data.nonfiniteIDs{end+1,1}=id;continue;end %#ok<AGROW>
    data.ids{end+1,1}=id;data.keys{end+1,1}=animalKey;data.values(end+1,1)=double(value); %#ok<AGROW>
end
for i=1:numel(allKeys)
    if sum(strcmp(allKeys,allKeys{i}))>1 && ~any(strcmp(data.duplicateIDs,allIDs{i}))
        data.duplicateIDs{end+1,1}=allIDs{i}; %#ok<AGROW>
    end
end
end

function adjusted=adjustP(raw,method,familySize)
adjusted=nan(size(raw));finite=isfinite(raw);
if strcmp(method,'None'),adjusted(finite)=raw(finite);return;end
if strcmp(method,'Bonferroni'),adjusted(finite)=min(1,raw(finite)*familySize);return;end
% Unavailable selected tests are conservatively represented by p=1 when
% determining ranks, then restored to NaN in the reported adjusted values.
p=raw;p(~finite)=1;[ordered,index]=sort(p);running=0;
for rank=1:numel(index)
    running=max(running,(familySize-rank+1)*ordered(rank));
    if finite(index(rank)),adjusted(index(rank))=min(1,running);end
end
end

function p=tCDF(t,df)
if isnan(t),p=NaN;return;end
if isinf(t),p=double(t>0);return;end
z=df/(df+t*t);small=.5*betainc(z,df/2,.5);
if t<0,p=small;else,p=1-small;end
end

function t=tQuantile(p,df)
if p==.5,t=0;return;end
if p<=0,t=-Inf;return;elseif p>=1,t=Inf;return;end
beta=betaincinv(2*min(p,1-p),df/2,.5);
t=sign(p-.5)*sqrt(df*(1-beta)/beta);
end

function out=emptyComparison(alpha)
out=struct('leftKey','','rightKey','','leftLabel','','rightLabel','','test','','tail','both', ...
    'alternative','','nLeft',0,'nRight',0,'nPairs',0,'nAvailableLeft',0,'nAvailableRight',0, ...
    'leftAnimalIDs',{{}},'rightAnimalIDs',{{}},'pairedAnimalIDs',{{}}, ...
    'valuesLeft',zeros(0,1),'valuesRight',zeros(0,1), ...
    'unmatchedLeftIDs',{{}},'unmatchedRightIDs',{{}},'unmatchedIDs',{{}},'overlappingIDs',{{}}, ...
    'nonfiniteLeftIDs',{{}},'nonfiniteRightIDs',{{}},'duplicateLeftIDs',{{}},'duplicateRightIDs',{{}}, ...
    'meanLeft',NaN,'meanRight',NaN,'effect',NaN,'standardError',NaN, ...
    'ci',[NaN NaN],'confidenceLevel',1-alpha,'t',NaN,'df',NaN, ...
    'pRaw',NaN,'pAdjusted',NaN,'significant',false,'status','unavailable','warning','');
end

function out=readField(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function out=logicalSetting(value)
out=false;
if (islogical(value)||isnumeric(value))&&isscalar(value)&&isfinite(value),out=logical(value);
elseif ischar(value)||(isstring(value)&&isscalar(value)),out=any(strcmpi(strtrim(char(value)),{'true','yes','1','on'}));end
end

function out=addWarning(out,message)
if isempty(out),out=message;else,out=[out ' ' message];end
end
