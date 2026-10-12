function s=fusiFCLoadScan(s,index,progress)
% Keep the selected movie plus at most one working movie; never concatenate scans.
if nargin<3,progress=@(~,~)[];end
if ~isfield(s,'fcScanSequence')||isempty(s.fcScanSequence)||~isempty(s.subjects(index).I4),return;end
q=s.fcScanSequence;d=q.scans{index};file=fusiFindMovedDataPath(d.file);
original=isfield(s,'fcOriginalSubject')&&strcmp(d.key,q.originalKey);
unchanged=original&&isequaln(s.subjects(index).baseline,s.fcOriginalSubject.baseline)&&strcmpi(s.subjects(index).functionalSource,s.fcOriginalSubject.functionalSource)&& ...
    (~strcmpi(s.subjects(index).functionalSource,'PSC')||s.subjects(index).TR==s.fcOriginalSubject.TR);
if unchanged&&~isempty(s.fcOriginalSubject.I4)
    for j=1:s.nSub,if j~=s.currentSubject&&j~=index,s.subjects(j).I4=[];end,end
    s.subjects(index).I4=s.fcOriginalSubject.I4;return;
end
progress(0,['Loading ' d.label]);
memoryPower=[];
if original&&strcmpi(s.fcOriginalSubject.functionalSource,'I'),memoryPower=s.fcOriginalSubject.I4;
elseif ~isempty(d.memoryPower),memoryPower=d.memoryPower;end
if isempty(memoryPower),info=fusiBaselineFileInfo(file);else,info=struct('spatialSize',d.spatialSize,'nFrames',d.nFrames);end
assert(isequal(info.spatialSize,d.spatialSize)&&info.nFrames==d.nFrames, ...
    'deConfUSIon:FCScanChanged','This scan has changed. Remove it and select it again.');
for j=1:s.nSub
    if j~=s.currentSubject&&j~=index,s.subjects(j).I4=[];end
end
if ~isempty(memoryPower)
    I=single(memoryPower);
elseif info.partialReadable
    I=zeros(info.size,'single');spatial=info.spatialSize;
    chunk=max(1,floor(32*1024^2/(4*prod(spatial))));subs=repmat({':'},1,numel(info.size));
    for first=1:chunk:info.nFrames
        count=min(chunk,info.nFrames-first+1);subs{end}=first:first+count-1;
        I(subs{:})=single(h5read(file,info.path,[ones(1,numel(spatial)) first],[spatial count]));
        progress((first+count-1)/info.nFrames,['Loading ' d.label]);
    end
elseif ~isempty(info.data)
    I=single(info.data);info.data=[];
else
    [D,~]=loadFUSIData(file,d.TR);I=single(D.I);
end
anchor=q.scans{find(cellfun(@(c)strcmp(c.key,q.originalKey),q.scans),1)};
I=fusiScanSequence('mapSeries',I,d,anchor);
if ndims(I)==3,I=reshape(I,size(I,1),size(I,2),1,size(I,3));end
assert(isequal(size(I,[1 2 3]),[s.Y s.X s.Z]),'deConfUSIon:FCScanGrid', ...
    'Scans must map to the retained FC grid. Register the native scans to a common atlas grid first.');
if strcmpi(s.subjects(index).functionalSource,'PSC')
    b=s.subjects(index).baseline;
    P=computePSC(I,d.TR,struct('interpol',1),b);I=P.PSC;
end
s.subjects(index).I4=I;s.subjects(index).TR=d.TR;
s.subjects(index).referenceValid=isfinite(mean(I,4))&max(I,[],4)>min(I,[],4);
s.subjects(index)=fusiFCExcludeNonTissue(s.subjects(index));
progress(1,['Loaded ' d.label]);
end
