function info=fusiBaselineFileInfo(file)
% Inspect a reference without reading its multi-GB movie. Studio I stays native.
info=struct('file',file,'path','','size',[],'TR',NaN,'acquisitionTR',NaN, ...
    'metadata',struct(),'data',[],'partialReadable',false);
stat=dir(file);if ~isempty(stat),info.fileBytes=stat.bytes;info.fileDatenum=stat.datenum;end
for path={'/newData/I','/I','/IQR','/data/I','/img','/image','/volume'}
    try
        h=h5info(file,path{1});sz=double(h.Dataspace.Size);
        if numel(sz)>=3&&numel(sz)<=4
            info.path=path{1};info.size=sz;info.partialReadable=true;break;
        end
    catch
    end
end
if info.partialReadable
    prefix='';if startsWith(info.path,'/newData/'),prefix='/newData';elseif startsWith(info.path,'/data/'),prefix='/data';end
    info.TR=smallScalar(file,[prefix '/TR']);
    info.acquisitionTR=smallScalar(file,[prefix '/acquisitionTiming/TR']);
else
    % Classic MAT files cannot slice nested arrays on disk. Load only at Apply.
    vars=whos('-file',file);names={vars.name};
    for key={'I','IQR','img','image','volume','newData','data'}
        j=find(strcmp(names,key{1}),1);if isempty(j),continue;end
        if any(strcmp(key{1},{'newData','data'}))
            S=load(file,key{1});D=S.(key{1});
            assert(isfield(D,'I'),'deConfUSIon:BaselineFile','Saved dataset has no absolute Doppler I array.');
            info.data=D.I;info.size=size(D.I);info.path=['/' key{1} '/I'];
            if isfield(D,'TR'),info.TR=D.TR;end
            if isfield(D,'acquisitionTiming'),info.acquisitionTR=D.acquisitionTiming.TR;end
        elseif numel(vars(j).size)>=3
            info.path=['/' key{1}];info.size=vars(j).size;
        end
        if ~isempty(info.size),break;end
    end
    if any(strcmp(names,'TR')),S=load(file,'TR');info.TR=S.TR;end
end
assert(~isempty(info.size),'deConfUSIon:BaselineFile','Select a raw or preprocessed Doppler MAT time series.');
info.spatialSize=info.size(1:end-1);info.nFrames=info.size(end);
try
    vars=whos('-file',file);names={vars.name};small=intersect(names,{'metadata','md'});
    if ~isempty(small)
        S=load(file,small{:});if isfield(S,'metadata'),info.metadata=S.metadata;elseif isfield(S,'md'),info.metadata=S.md;end
    end
catch
end
end
function v=smallScalar(file,path)
v=NaN;try,x=h5read(file,path);if isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0,v=double(x);end;catch,end
end
