function selected=scmSelectScanCandidates(pool,scanKey)
% One strongest candidate per region/role/slice, across all or one scan.
if nargin<2,scanKey='';end
selected={};
for k=1:numel(pool)
    c=pool{k};
    if ~isempty(scanKey)&&(~isfield(c,'searchScanKey')||~strcmp(c.searchScanKey,scanKey)),continue;end
    key=scmCandidateRegionKey(c);
    index=find(cellfun(@(a)a.slice==c.slice&&strcmp(a.role,c.role)&&strcmp(scmCandidateRegionKey(a),key),selected),1);
    if isempty(index),selected{end+1}=c; %#ok<AGROW>
    elseif c.meanPSC>selected{index}.meanPSC,selected{index}=c;end
end
end
