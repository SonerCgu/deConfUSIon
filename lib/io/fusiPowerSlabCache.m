function slab=fusiPowerSlabCache(info,lo,hi,frames)
% Bounded read-only cache: nearby ROIs reuse native slices or raw-data tiles.
% No more than 128 MB is retained and each read is at most 16 MB.
persistent entries
if isempty(entries),entries={};end
slab=[];shape=info.spatialSize;dimensions=numel(shape);lo=lo(1:dimensions);hi=hi(1:dimensions);
start=lo;stop=hi;start(1:2)=1;stop(1:2)=shape(1:2);n=numel(frames);
if prod(stop-start+1)*n*4>16*1024^2
    start(1:2)=1+16*floor((lo(1:2)-1)/16);stop(1:2)=min(shape(1:2),16*ceil(hi(1:2)/16));
end
extent=stop-start+1;bytes=prod(extent)*n*4;if bytes>16*1024^2,return;end
signature=[];if isfield(info,'fileBytes'),signature=[info.fileBytes info.fileDatenum];end
key={info.file,info.path,start,stop,frames(1),frames(end),signature};
for k=1:numel(entries)
    saved=entries{k};sameSource=isequal(saved.key([1 2 5 6 7]),key([1 2 5 6 7]));
    if sameSource&&all(saved.start<=lo)&&all(saved.stop>=hi)
        slab=saved;entries(k)=[];entries{end+1}=slab;return;
    end
end
A=h5read(info.file,info.path,[start frames(1)],[extent n]);
slab=struct('key',{key},'start',start,'stop',stop,'frames',frames,'power',reshape(single(A),[extent n]),'bytes',bytes);
while ~isempty(entries)&&(numel(entries)>=24||sum(cellfun(@(s)s.bytes,entries))+bytes>128*1024^2),entries(1)=[];end
entries{end+1}=slab;
end
