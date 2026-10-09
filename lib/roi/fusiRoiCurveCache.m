function series=fusiRoiCurveCache(action,key,series)
% Reuse individual file-backed curves across scan ordering and ROI redraws.
persistent entries
if isempty(entries),entries={};end
for k=1:numel(entries)
    if isequaln(entries{k}.key,key)
        saved=entries{k};entries(k)=[];
        if strcmp(action,'get'),entries{end+1}=saved;series=saved.series;return;end
        break;
    end
end
if strcmp(action,'get'),series=[];return;end
bytes=16*numel(series.PSC)+8*(numel(key.voxels)+numel(key.baseline));
if bytes>32*1024^2,return;end
while ~isempty(entries)&&(numel(entries)>=256||sum(cellfun(@(e)e.bytes,entries))+bytes>32*1024^2),entries(1)=[];end
entries{end+1}=struct('key',key,'series',series,'bytes',bytes);
end
