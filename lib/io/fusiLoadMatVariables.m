function [S,timing]=fusiLoadMatVariables(file,names,progress)
% Preserve load(file,names{:}) values, with bounded partial reads when supported.
if nargin<3,progress=[];end
stageClock=tic;
[readFile,cached,cacheState]=fusiLocalMatReadSource(file,@copyProgress);
timing=struct('sourceFile',file,'readFile',readFile,'usedLocalCache',cached,'cacheState',cacheState, ...
    'sourceStagingSeconds',toc(stageClock),'readSeconds',NaN);
readClock=tic;
if isempty(progress),S=load(readFile,names{:});timing.readSeconds=toc(readClock);return;end
originalProgress=progress;
if cached,progress=@(fraction,message)originalProgress(.35+.65*fraction,message);end
file=readFile;
info=whos('-file',file);info=info(ismember({info.name},names));
partial=false;try,partial=H5F.is_hdf5(file);catch,end
total=max(1,sum(double([info.bytes])));done=0;S=struct();
location='';if cached,location=' from local cache';end
numericClasses={'single','double','uint8','uint16','uint32','uint64','int8','int16','int32','int64','logical'};
for k=1:numel(info)
    item=info(k);first=done/total;last=(done+double(item.bytes))/total;
    if partial&&numel(item.size)>=3&&~item.sparse&&any(strcmp(item.class,numericClasses))
        progress(first,['Reading ' item.name location '...']);
        if strcmp(item.class,'logical'),array=false(item.size);else,array=zeros(item.size,item.class);end
        if item.complex,array=complex(array);end
        frames=item.size(end);bytesPerFrame=max(1,double(item.bytes)/max(1,frames));
        chunk=max(1,min(ceil(frames/8),floor(32*1024^2/bytesPerFrame)));
        source=matfile(file);subs=repmat({':'},1,numel(item.size));
        for start=1:chunk:frames
            stop=min(frames,start+chunk-1);subs{end}=start:stop;
            array(subs{:})=subsref(source,substruct('.',item.name,'()',subs));
            progress(first+(last-first)*stop/max(1,frames),sprintf('Reading %s%s: %d / %d frames',item.name,location,stop,frames));
        end
        S.(item.name)=array;
    else
        % MATLAB's classic/structured reader has no byte-progress callback.
        if cached,message=['Reading ' item.name ' from local cache...'];
        else,message=['Reading ' item.name ' from disk...'];end
        progress(NaN,message);
        value=load(file,item.name);S.(item.name)=value.(item.name);
        progress(last,['Read ' item.name]);
    end
    done=done+double(item.bytes);
end
progress(1,'File read complete');
timing.readSeconds=toc(readClock);
    function copyProgress(fraction,message)
        if ~isempty(progress),progress(.35*fraction,message);end
    end
end
