function specs=gaTitrationComparisonSpecs(D,S)
% One shared selection for the dialog, plotted p-values and exported tests.
% On first use, select one-tailed Student tests of each dose > aCSF.
% Unselected dose-to-dose comparisons start two-sided. An explicit selection,
% including Clear all, is retained instead of being overwritten by defaults.
categories=readField(D,'categories',struct([]));
saved=readField(S,'titrationComparisons',struct([]));
if ~isstruct(saved),saved=struct([]);end
tests={'Paired t-test','Welch t-test','Student t-test'};tails={'both','right','left'};
specs=struct('left',{},'right',{},'test',{},'tail',{},'show',{});
for i=1:numel(categories)-1
    for j=i+1:numel(categories)
        left=i;right=j;
        if ~isfinite(categories(i).doseM)&&isfinite(categories(j).doseM),left=j;right=i;
        elseif isfinite(categories(i).doseM)&&isfinite(categories(j).doseM)&&categories(i).doseM>categories(j).doseM
            left=j;right=i;
        end
        controlPair=xor(isfinite(categories(left).doseM),isfinite(categories(right).doseM));
        tail='both';if controlPair,tail='right';end
        selected=isempty(saved)&&controlPair;
        specs(end+1)=struct('left',char(categories(left).key),'right',char(categories(right).key), ...
            'test','Student t-test','tail',tail,'show',selected); %#ok<AGROW>
    end
end
for i=1:numel(saved)
    left=char(readField(saved(i),'left',''));right=char(readField(saved(i),'right',''));
    if isempty(left)||isempty(right)||strcmp(left,right),continue;end
    hit=find(arrayfun(@(x)(strcmp(x.left,left)&&strcmp(x.right,right))|| ...
        (strcmp(x.left,right)&&strcmp(x.right,left)),specs),1);
    request=struct('left',left,'right',right, ...
        'test',canonical(readField(saved(i),'test','Student t-test'),tests,'Student t-test'), ...
        'tail',canonical(readField(saved(i),'tail','both'),tails,'both'), ...
        'show',asLogical(readField(saved(i),'show',false)));
    if isempty(hit),specs(end+1)=request;else,specs(hit)=request;end %#ok<AGROW>
end
end

function out=readField(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function value=canonical(value,choices,fallback)
value=char(value);hit=find(strcmpi(value,choices),1);
if isempty(hit),value=fallback;else,value=choices{hit};end
end

function value=asLogical(value)
if ischar(value)||isstring(value),value=any(strcmpi(strtrim(char(value)),{'true','1','yes','on'}));
else,value=isscalar(value)&&~isempty(value)&&isfinite(value)&&logical(value);end
end
