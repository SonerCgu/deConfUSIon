function C=gaTitrationCategories(R,S)
% Single aCSF category followed by concentration categories. Statistics and
% plotted dots share these exact, equally weighted animal-level measurements.
T=R.subjTable;values=double(R.metricVals(:));dose=gaTitration('doses',T,S);
n=size(T,1);groups=cell(n,1);conditions=groups;animals=groups;ids=groups;
sources=gaTitration('keys',T);recordings=sources;
for i=1:n
    groups{i}=strtrim(char(T{i,3}));conditions{i}=strtrim(char(T{i,4}));
    [ids{i},info]=gaAnimalIdentity(T(i,:));animals{i}=info.key;
    if ~isempty(info.recording.scanID),recordings{i}=info.recording.key;end
end
warnings={};choice=setting(S,'titrationControlGroup','Auto');
available=uniqueCI(groups);controlGroup='';
if strcmpi(choice,'Auto')
    for name={'aCSF','Vehicle','Control'}
        hit=find(strcmpi(available,name{1}),1);if ~isempty(hit),controlGroup=available{hit};break;end
    end
elseif any(strcmpi(available,choice)),controlGroup=char(choice);
end
isControl=strcmpi(groups,controlGroup)&~isempty(controlGroup);
controlCondition=setting(S,'titrationControlCondition','Auto');
if strcmp(controlCondition,'<Unspecified>'),controlCondition='';end
availableConditions=uniqueCI(conditions(isControl));
if strcmpi(controlCondition,'Auto')
    if numel(availableConditions)==1,controlCondition=availableConditions{1};
    elseif numel(availableConditions)>1
        warnings{end+1}='Select one aCSF Condition in Assign doses; different control conditions are not pooled automatically.';
        controlCondition='';isControl(:)=false;
    end
end
selectedControl=isControl&strcmpi(conditions,controlCondition);
controlLike=strcmpi(groups,'Control')|strcmpi(groups,'Vehicle')|strcmpi(groups,'aCSF')|strcmpi(groups,controlGroup);
treatment=~controlLike;
if isempty(controlGroup),warnings{end+1}='No aCSF group identified. Choose its source Group in Assign doses.';end
excludedControl=find(controlLike&~selectedControl);
if ~isempty(excludedControl)
    warnings{end+1}=sprintf('%d control row(s) outside the selected aCSF Group/Condition are omitted.',numel(excludedControl));
end
cats=struct('key',{},'label',{},'doseM',{},'group',{},'condition',{},'role',{});
rowCategory=repmat({''},n,1);
if any(selectedControl)
    key=['acsf|' lower(controlGroup) '|' lower(char(controlCondition))];
    cats(end+1)=struct('key',key,'label','aCSF','doseM',NaN,'group',controlGroup, ...
        'condition',char(controlCondition),'role','control');
    rowCategory(selectedControl)={key};
end
treatmentGroups=uniqueCI(groups(treatment&isfinite(dose)));
allDoses=sort(unique(dose(treatment&isfinite(dose))));
for d=allDoses(:)'
    for g=1:numel(treatmentGroups)
        name=treatmentGroups{g};conds=uniqueCI(conditions(treatment&strcmpi(groups,name)&isfinite(dose)));
        for k=1:numel(conds)
            rows=treatment&dose==d&strcmpi(groups,name)&strcmpi(conditions,conds{k});
            if ~any(rows),continue;end
            [~,label]=gaTitration('parse',d);key=sprintf('dose|%.12g|%s|%s',d,lower(name),lower(conds{k}));
            if numel(treatmentGroups)>1,label=[label ' / ' name];end
            if numel(conds)>1,condition=conds{k};if isempty(condition),condition='Unspecified';end;label=[label ' / ' condition];end
            cats(end+1)=struct('key',key,'label',label,'doseM',d,'group',name,'condition',conds{k},'role','treatment'); %#ok<AGROW>
            rowCategory(rows)={key};
        end
    end
end
points=struct('animalID',{},'animalKey',{},'categoryKey',{},'label',{},'doseM',{}, ...
    'group',{},'condition',{},'value',{},'nScans',{},'rows',{});
for c=1:numel(cats)
    atCategory=find(strcmp(rowCategory,cats(c).key)&isfinite(values)&~cellfun(@isempty,animals));
    animalKeys=unique(animals(atCategory),'stable');
    for a=1:numel(animalKeys)
        idx=atCategory(strcmp(animals(atCategory),animalKeys{a}));
        [~,u]=unique(sources(idx),'stable');uniqueRows=idx(u);
        scanKeys=unique(recordings(uniqueRows),'stable');scanMeans=zeros(size(scanKeys));
        for k=1:numel(scanKeys),scanMeans(k)=mean(values(uniqueRows(strcmp(recordings(uniqueRows),scanKeys{k}))));end
        points(end+1)=struct('animalID',ids{idx(1)},'animalKey',animalKeys{a},'categoryKey',cats(c).key, ...
            'label',cats(c).label,'doseM',cats(c).doseM,'group',cats(c).group,'condition',cats(c).condition, ...
            'value',mean(scanMeans),'nScans',numel(scanMeans),'rows',idx(:)'); %#ok<AGROW>
    end
end
means=nan(1,numel(cats));sd=means;sem=means;counts=zeros(size(means));
for c=1:numel(cats)
    hit=strcmp({points.categoryKey},cats(c).key);v=[points(hit).value];counts(c)=numel(v);
    if isempty(v),continue;end
    means(c)=mean(v);if numel(v)>1,sd(c)=std(v,0);sem(c)=sd(c)/sqrt(numel(v));end
end
C=struct('categories',cats,'categoryPoints',points,'categoryMean',means,'categorySD',sd,'categorySEM',sem, ...
    'categoryN',counts,'rowCategoryKeys',{rowCategory},'controlGroup',controlGroup, ...
    'controlCondition',char(controlCondition),'categoryWarnings',{warnings},'excludedControlRows',excludedControl(:)', ...
    'unassignedRows',find(treatment&~isfinite(dose))', ...
    'missingAnimalRows',find(~cellfun(@isempty,rowCategory)&isfinite(values)&cellfun(@isempty,animals))');
end

function out=setting(S,name,fallback)
out=fallback;if isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function out=uniqueCI(values)
[~,idx]=unique(lower(string(values)),'stable');out=values(idx);
end
