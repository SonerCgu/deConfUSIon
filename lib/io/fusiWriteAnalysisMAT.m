function fusiWriteAnalysisMAT(file,payload,progress,options)
% Write a MATLAB-compatible scalar newData struct with bounded image chunks.
% Small/unusual payloads retain MATLAB save(). The caller owns verification
% and atomic publication; this file must remain a private staging file.
if nargin<3,progress=[];end
if nargin<4,options=struct();end
minimum=128*1024^2;if isfield(options,'minimumBytes'),minimum=options.minimumBytes;end
chunkBytes=64*1024^2;if isfield(options,'chunkBytes'),chunkBytes=options.chunkBytes;end
image=payload.newData.I;info=whos('image');
chunked=info.bytes>=minimum&&isreal(image)&&any(strcmp(class(image),{'single','double'}))&&~issparse(image);
if ~chunked
 report(0,'Writing MATLAB result...');save(file,'-struct','payload','-v7.3','-nocompression');report(.9,'MAT write complete; verifying...');return;
end
metadata=payload;metadata.newData.I=zeros(0,'like',image);
report(0,'Writing result metadata...');save(file,'-struct','metadata','-v7.3','-nocompression');
% MATLAB stores a scalar struct as a group. Retain its field metadata and
% replace only the empty I dataset with the acquired-size numeric dataset.
id=H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');
try,H5L.delete(id,'/newData/I','H5P_DEFAULT');H5F.close(id);catch ME,H5F.close(id);rethrow(ME);end
shape=size(image);T=shape(end);bytesPerFrame=info.bytes/T;
count=max(1,min(T,floor(chunkBytes/max(1,bytesPerFrame))));chunk=shape;chunk(end)=count;
h5create(file,'/newData/I',shape,'Datatype',class(image),'ChunkSize',chunk);
h5writeatt(file,'/newData/I','MATLAB_class',class(image));
subs=repmat({':'},1,ndims(image));start=ones(1,ndims(image));extent=shape;
for first=1:count:T
 last=min(T,first+count-1);subs{end}=first:last;start(end)=first;extent(end)=last-first+1;
 h5write(file,'/newData/I',image(subs{:}),start,extent);
 report(.9*last/T,sprintf('Writing result MAT: %.0f / %.0f MiB',last*bytesPerFrame/1024^2,info.bytes/1024^2));
end
 function report(fraction,message)
  if ~isempty(progress),progress(fraction,message);else,drawnow limitrate nocallbacks;end
 end
end
