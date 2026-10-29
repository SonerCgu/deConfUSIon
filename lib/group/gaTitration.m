function varargout=gaTitration(action,varargin)
% Concentration assignments and descriptive animal-level dose-response plots.
switch lower(action)
    case 'parse', [varargout{1:nargout}]=parseDose(varargin{:});
    case 'keys', varargout{1}=rowKeys(varargin{:});
    case 'assign', varargout{1}=assignRows(varargin{:});
    case 'doses', varargout{1}=rowDoses(varargin{:});
    case 'summarize', varargout{1}=summarize(varargin{:});
    case 'plot', varargout{1}=gaTitrationPlot(varargin{:});
    case 'sheets', [varargout{1:nargout}]=sheets(varargin{:});
    case 'comparisonsheet', varargout{1}=comparisonSheet(varargin{:});
    case 'layoutannotations', gaTitrationBrackets('layout',varargin{:});
    otherwise, error('GroupAnalysis:TitrationAction','Unknown titration action: %s',action);
end
end

function [m,label]=parseDose(value)
% Blank clears an assignment. Numeric stored values are molar concentrations.
m=NaN;label='';
if isempty(value),return;end
if isnumeric(value)
    if ~isscalar(value)||~isfinite(value)||value<=0
        error('GroupAnalysis:TitrationDose','Concentration must be positive and finite.');
    end
    m=double(value);
else
    value=strtrim(char(value));if isempty(value),return;end
    value=strrep(strrep(value,char(181),'u'),char(956),'u');
    t=regexpi(value,'^([+]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)\s*(pM|nM|uM|mM|M)$','tokens','once');
    if isempty(t),error('GroupAnalysis:TitrationDose','Enter a concentration with units, for example 100 pM, 10 nM or 1 uM.');end
    units={'pm','nm','um','mm','m'};scale=[1e-12 1e-9 1e-6 1e-3 1];
    m=str2double(t{1})*scale(strcmpi(t{2},units));
    if ~isfinite(m)||m<=0,error('GroupAnalysis:TitrationDose','Concentration must be positive and finite.');end
end
% Equivalent unit spellings must resolve to exactly the same dose bin.
m=str2double(sprintf('%.12g',m));
if m<1e-9,scale=1e-12;unit='pM';
elseif m<1e-6,scale=1e-9;unit='nM';
elseif m<1e-3,scale=1e-6;unit='uM';
elseif m<1,scale=1e-3;unit='mM';
else,scale=1;unit='M';end
label=sprintf('%.9g %s',m/scale,unit);
end

function keys=rowKeys(T)
% File identity survives sorting, exclusions and edits of Group/Condition/ID.
keys=cell(size(T,1),1);
for i=1:size(T,1)
    file='';
    for j=[7 6 8]
        if size(T,2)>=j && ~isempty(strtrim(char(T{i,j}))),file=strtrim(char(T{i,j}));break;end
    end
    file=strrep(file,'\','/');
    if ispc||~isempty(regexp(file,'^(?:[A-Za-z]:/|//)','once')),file=lower(file);end
    keys{i}=file;
end
end

function A=assignRows(A,T,rows,dose)
if isempty(A),A=cell(0,2);end
[m,~]=parseDose(dose);keys=rowKeys(T);
for i=rows(:)'
    if isempty(keys{i}),error('GroupAnalysis:TitrationSource','Row %d needs an ROI/data file before assigning a dose.',i);end
    hit=strcmp(A(:,1),keys{i});A(hit,:)=[];
    if isfinite(m),A(end+1,:)={keys{i},m};end %#ok<AGROW>
end
end

function doses=rowDoses(T,S)
doses=nan(size(T,1),1);A=field(S,'titrationAssignments',cell(0,2));
if isempty(A),return;end
if ~iscell(A)||size(A,2)~=2,error('GroupAnalysis:TitrationAssignments','Invalid saved concentration assignments.');end
keys=rowKeys(T);
for i=1:numel(keys)
    hits=find(strcmp(A(:,1),keys{i}));
    if isempty(keys{i})||isempty(hits),continue;end
    stored=cellfun(@(v)parseDose(v),A(hits,2));
    if numel(unique(stored))~=1,error('GroupAnalysis:TitrationAssignments','Conflicting concentrations for source row %d.',i);end
    doses(i)=stored(1);
end
end

function D=summarize(R,S)
T=R.subjTable;v=double(R.metricVals(:));assert(numel(v)==size(T,1));
dose=rowDoses(T,S);keys=rowKeys(T);n=numel(v);
series=cell(n,1);animal=cell(n,1);ids=cell(n,1);condition=cell(n,1);recording=keys;
for i=1:n
    g=strtrim(char(T{i,3}));condition{i}=strtrim(char(T{i,4}));
    conditions=T(strcmpi(T(:,3),g),4);
    if numel(unique(lower(string(conditions))))>1
        c=condition{i};if isempty(c),c='Unspecified';end
        series{i}=[g ' / ' c];
    else,series{i}=g;end
    [ids{i},identity]=gaAnimalIdentity(T(i,:));animal{i}=identity.key;
    if ~isempty(identity.recording.scanID),recording{i}=identity.recording.key;end
end
valid=isfinite(v)&isfinite(dose)&~cellfun(@isempty,animal);
points=struct('animalID',{},'animalKey',{},'doseM',{},'doseLabel',{},'series',{}, ...
    'group',{},'condition',{},'value',{},'nScans',{},'rows',{});
assigned=find(valid);taken=false(n,1);
for i=assigned(:)'
    if taken(i),continue;end
    idx=find(valid & dose==dose(i) & strcmp(animal,animal{i}) & strcmpi(series,series{i}));
    taken(idx)=true;
    [~,u]=unique(keys(idx),'stable');uniqueRows=idx(u);
    scanKeys=unique(recording(uniqueRows),'stable');scanValues=nan(size(scanKeys));
    for k=1:numel(scanKeys),scanValues(k)=mean(v(uniqueRows(strcmp(recording(uniqueRows),scanKeys{k}))));end
    [~,label]=parseDose(dose(i));
    points(end+1)=struct('animalID',ids{i},'animalKey',animal{i},'doseM',dose(i), ...
        'doseLabel',label,'series',series{i},'group',char(T{i,3}),'condition',condition{i}, ...
        'value',mean(scanValues),'nScans',numel(scanKeys),'rows',idx(:)'); %#ok<AGROW>
end
doses=unique(dose(valid));doses=sort(doses);labels=cell(size(doses));
for i=1:numel(doses),[~,labels{i}]=parseDose(doses(i));end
names=unique(series(valid),'stable');
mu=nan(numel(doses),numel(names));sd=mu;sem=mu;counts=zeros(size(mu));
for d=1:numel(doses)
    for g=1:numel(names)
        hit=arrayfun(@(p)p.doseM==doses(d)&&strcmpi(p.series,names{g}),points);
        values=[points(hit).value];counts(d,g)=numel(values);
        if isempty(values),continue;end
        mu(d,g)=mean(values);
        if numel(values)>1,sd(d,g)=std(values,0);sem(d,g)=sd(d,g)/sqrt(numel(values));end
    end
end
D=struct('dosesM',doses,'doseLabels',{labels},'seriesNames',{names},'points',points, ...
    'mean',mu,'sd',sd,'sem',sem,'nAnimals',counts,'rowDosesM',dose, ...
    'unassignedRows',find(~isfinite(dose))','nonfiniteRows',find(~isfinite(v))', ...
    'missingAnimalRows',find(isfinite(dose)&isfinite(v)&cellfun(@isempty,animal))', ...
    'aggregation','Deduplicate source files, average ROIs within identified recordings, then average scans within animal/concentration/Group/Condition; equal animal weights. Files without a scan identity remain separate within-animal sources.', ...
    'inference','Selected pairwise tests of displayed animal means; no pooled test across doses.', ...
    'xScale',field(S,'titrationXScale','Equal spacing'),'errorBand',field(S,'titrationErrorBand','None'));
C=gaTitrationCategories(R,S);names=fieldnames(C);
for i=1:numel(names),D.(names{i})=C.(names{i});end
testSettings=S;testSettings.alpha=field(S,'titrationAlpha',field(S,'alpha',.05));
testSettings.titrationComparisons=gaTitrationComparisonSpecs(D,S);
D.comparisonResults=gaTitrationComparisons(D,testSettings);
displayMode=field(S,'titrationPDisplay','Both');if strcmpi(displayMode,'p-values'),displayMode='Both';end
D.comparisonSettings=struct('specifications',testSettings.titrationComparisons, ...
    'alpha',testSettings.alpha,'correction',field(S,'titrationCorrection','None'), ...
    'display',displayMode,'show',field(S,'titrationShowP',true));
end

function [rows,animals,summary]=sheets(R,S)
D=summarize(R,S);T=R.subjTable;
rows={'Analysis row','Animal','Group','Condition','ROI file','Concentration (M)','Concentration','Metric','Plot category'};
for i=1:size(T,1)
    label='';if isfinite(D.rowDosesM(i)),[~,label]=parseDose(D.rowDosesM(i));end
    category='';c=find(strcmp({D.categories.key},D.rowCategoryKeys{i}),1);
    if ~isempty(c),category=D.categories(c).label;end
    rows(end+1,:)={i,T{i,2},T{i,3},T{i,4},T{i,7},D.rowDosesM(i),label,R.metricVals(i),category}; %#ok<AGROW>
end
animals={'Animal','Group','Condition','Concentration (M)','Plot category','Animal mean','Unique scans','Analysis rows'};
for p=D.categoryPoints,animals(end+1,:)={p.animalID,p.group,p.condition,p.doseM,p.label,p.value,p.nScans,mat2str(p.rows)};end %#ok<AGROW>
summary={'Category','Concentration (M)','Group','N animals','Mean','SD','SEM','Condition'};
for c=1:numel(D.categories)
    a=D.categories(c);
    summary(end+1,:)={a.label,a.doseM,a.group,D.categoryN(c),D.categoryMean(c),D.categorySD(c),D.categorySEM(c),a.condition}; %#ok<AGROW>
end
end

function C=comparisonSheet(D)
result=D.comparisonResults;
C={'Left','Right','Test','Alternative','N left used','N right used','N pairs','p raw','p adjusted','Correction','Family size', ...
    'Effect left-right','CI lower','CI upper','Confidence level','t','df','Status','Notes','Left animal IDs','Right animal IDs', ...
    'Unmatched left','Unmatched right','Left values','Right values'};
for t=result.comparisons
    C(end+1,:)={t.leftLabel,t.rightLabel,t.test,t.alternative,t.nLeft,t.nRight,t.nPairs,t.pRaw,t.pAdjusted, ...
        result.correction,result.familySize,t.effect,t.ci(1),t.ci(2),t.confidenceLevel,t.t,t.df,t.status, ...
        strjoin({t.warning,result.ciNote,result.familyNote},' '),strjoin(t.leftAnimalIDs,', '),strjoin(t.rightAnimalIDs,', '), ...
        strjoin(t.unmatchedLeftIDs,', '),strjoin(t.unmatchedRightIDs,', '),mat2str(t.valuesLeft'),mat2str(t.valuesRight')}; %#ok<AGROW>
end
for i=1:numel(C)
    if isnumeric(C{i})&&isscalar(C{i})&&isinf(C{i}),C{i}=num2str(C{i});end
end
end

function out=field(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end
