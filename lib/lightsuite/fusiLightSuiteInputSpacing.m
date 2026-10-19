function [mm,source]=fusiLightSuiteInputSpacing(data,meta,filename)
% Prefer current dataset geometry, then inspect its saved header if needed.
[mm,source]=fusiLightSuiteSpacing(struct('data',data,'meta',meta));
if ~isempty(mm)||contains(source,'permuted')||isempty(filename)||~isfile(filename),return;end
header=fusiLightSuiteReadMetadata(filename);
if isstruct(data)&&isfield(data,'I')&&~isempty(data.I)
    if ~isfield(header,'lightSuiteInputSize')||numel(header.lightSuiteInputSize)<3,return;end
    if ~isequal(double(size(data.I,1:3)),double(header.lightSuiteInputSize(1:3))),return;end
end
[mm,source]=fusiLightSuiteSpacing(header);
end
