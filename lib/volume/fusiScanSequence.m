function varargout=fusiScanSequence(action,varargin)
% Small scan descriptors, shared normalization and physical ROI correspondence.
switch action
    case 'maxScans',varargout{1}=10;
    case 'init',varargout{1}=initialise(varargin{:});
    case 'describe',varargout{1}=describe(varargin{:});
    case 'reference',varargout{1}=includeReference(varargin{:});
    case 'commonBaseline',varargout{1}=commonBaseline(varargin{:});
    case 'prepare',[varargout{1:nargout}]=prepare(varargin{:});
    case 'layout',varargout{1}=sequenceLayout(varargin{:});
    case 'sort',varargout{1}=sortScans(varargin{:});
    case 'trace',[varargout{1:nargout}]=sequenceTrace(varargin{:});
    case 'load',[varargout{1:nargout}]=loadScan(varargin{:});
    case 'mapROI',varargout{1}=mapROI(varargin{:});
    case 'mapVolume',varargout{1}=mapVolume(varargin{:});
    case 'mapSeries',varargout{1}=mapSeries(varargin{:});
    case 'offset',[varargout{1:nargout}]=gridOffset(varargin{:});
    case 'included',varargout{1}=includedScans(varargin{1});
    case 'shareAtlas'
        q=varargin{1};varargout{1}=~isfield(q,'shareAtlasMapping')||q.shareAtlasMapping;
    case 'labels',varargout{1}=cellfun(@(d)d.label,varargin{1}.scans,'UniformOutput',false);
    otherwise,error('deConfUSIon:ScanSequenceAction','Unknown scan sequence action.');
end
end
function q=initialise(par,I,TR,label)
if isfield(par,'scanSequence')&&isstruct(par.scanSequence)&&isfield(par.scanSequence,'scans')
    q=par.scanSequence;
    if ~isfield(par,'fusiSequencePowerFile')
        q.originalKey=originalKey(par,q);return;
    elseif ~isempty(par.fusiSequencePowerFile)
        chosen=fusiFindMovedDataPath(par.fusiSequencePowerFile);
        index=find(cellfun(@(d)strcmpi(d.file,chosen),q.scans),1);
        if ~isempty(index),q.active=index;q.originalKey=originalKey(par,q);return;end
    end
    % A different or unsaved Studio entry must initialize its own descriptor.
end
d=emptyDescriptor();d.label=label;d.TR=TR;d.rawTR=fusiBaselineAcquisitionTR(par,TR,ndims(I)==4);
d.geometry=geometry(par);d.spatialSize=size(I,1:ndims(I)-1);d.nFrames=size(I,ndims(I));
if isfield(par,'loadedFile')&&~isempty(par.loadedFile)
    d.rawFile=char(par.loadedFile);
    if ~isfile(d.rawFile)&&isfield(par,'loadedPath'),d.rawFile=fullfile(par.loadedPath,d.rawFile);end
    d.rawFile=fusiFindMovedDataPath(d.rawFile);
end
if isfield(par,'fusiSequencePowerFile'),d.file=fusiFindMovedDataPath(par.fusiSequencePowerFile);end
if isempty(d.file)&&isfield(par,'activeDataset')&&strcmp(par.activeDataset,'raw')&&isfile(d.rawFile),d.file=d.rawFile;end
if isempty(d.file)||~isfile(d.file),d.file='';d.memoryPower=I;end
d.acquiredTime=acquisitionTime(d.rawFile,d.geometry);
if ~isempty(d.file),d.fileInfo=fusiBaselineFileInfo(d.file);d.fileInfo.data=[];end
d.label=scanLabel(d.rawFile,label);d.key=d.file;
if isempty(d.key),d.label=[d.label ' | ' label];d.key=['memory:' d.label];end
q=struct('version',1,'scans',{{d}},'active',1,'originalKey',d.key,'orderMode','time', ...
    'normMode','shared','localWindowSec',[NaN NaN],'localReferences',{{}},'sharedReference',[],'shareAtlasMapping',true);
end
function d=emptyDescriptor()
d=struct('rawFile','','file','','label','','key','','TR',NaN,'rawTR',NaN, ...
    'nFrames',0,'spatialSize',[],'geometry',struct(),'memoryPower',[], ...
    'acquiredTime',NaN,'fileInfo',[],'includeTrace',true);
end
function key=originalKey(par,q)
key=q.scans{q.active}.key;
if isfield(par,'fusiOriginalScanKey')&&any(cellfun(@(d)strcmp(d.key,par.fusiOriginalScanKey),q.scans)),key=par.fusiOriginalScanKey;end
end
function d=describe(rawFile,file,label,rawTR)
d=emptyDescriptor();d.rawFile=fusiFindMovedDataPath(rawFile);d.file=fusiFindMovedDataPath(file);
raw=fusiBaselineFileInfo(d.rawFile);info=raw;if ~strcmpi(d.file,d.rawFile),info=fusiBaselineFileInfo(d.file);end
factor=1;
if ~strcmpi(d.file,d.rawFile)
    if isfinite(info.TR)&&isfinite(info.acquisitionTR),factor=info.TR/info.acquisitionTR;
    elseif raw.nFrames~=info.nFrames
        assert(mod(raw.nFrames,info.nFrames)==0,'deConfUSIon:ScanSequenceTR', ...
            'The saved averaging factor is unavailable. Choose a dataset with acquisition timing metadata.');
        factor=raw.nFrames/info.nFrames;
    end
end
assert(isscalar(rawTR)&&isfinite(rawTR)&&rawTR>0,'deConfUSIon:ScanSequenceTR','Acquisition TR must be positive.');
d.rawTR=rawTR;d.TR=rawTR*factor;d.nFrames=info.nFrames;d.spatialSize=info.spatialSize;
d.geometry=raw.metadata;d.label=[scanLabel(rawFile,label) ' | ' label];d.key=d.file;
d.acquiredTime=acquisitionTime(d.rawFile,d.geometry);info.data=[];d.fileInfo=info;
end
function q=includeReference(q,b)
if ~fusiBaselineReference('isExternal',b),return;end
r=b.reference;if ~isfield(r,'sourceFile')||isempty(r.sourceFile),return;end
file=fusiFindMovedDataPath(r.sourceFile);if ~isfile(file)||any(cellfun(@(d)strcmpi(d.file,file),q.scans)),return;end
if numel(q.scans)>=fusiScanSequence('maxScans'),return;end
d=emptyDescriptor();d.file=file;d.rawFile=r.rawFile;d.key=file;d.TR=r.TR;
d.rawTR=r.TR;if isfield(r,'rawTR'),d.rawTR=r.rawTR;end
d.nFrames=r.nFrames;d.spatialSize=r.spatialSize;
if isfield(r,'nativeSpatialSize'),d.spatialSize=r.nativeSpatialSize;end
if isfield(r,'sourceGeometry'),d.geometry=r.sourceGeometry;end
d.label=[scanLabel(d.rawFile,'Reference scan') ' | ' r.datasetLabel];
d.acquiredTime=acquisitionTime(d.rawFile,d.geometry);d.fileInfo=fusiBaselineFileInfo(file);d.fileInfo.data=[];
q.scans=[{d} q.scans];q.active=q.active+1;
if strcmp(q.orderMode,'time'),q=sortScans(q);end
end
function b=commonBaseline(q,b,I,TR,par)
if fusiBaselineReference('isExternal',b),return;end
local=b;w=[b.start b.end];
if isfield(b,'mode')&&(strncmpi(b.mode,'vol',3)||strncmpi(b.mode,'idx',3)),w=(w-1)*TR;end
d=q.scans{q.active};
r=fusiBaselineReference('build',I,TR,w,struct('sourceFile',d.file,'rawFile',d.rawFile, ...
    'datasetLabel',d.label,'rawTR',d.rawTR,'sourceGeometry',geometry(par)));
b.reference=r;b.localBaseline=local;b.start=r.windowSec(1);b.end=r.windowSec(2);b.mode='sec';
end
function L=sequenceLayout(q)
L=struct('startSec',{},'endSec',{},'nextSec',{},'label',{});start=0;
included=includedScans(q);
for k=1:numel(q.scans)
    d=q.scans{k};if ~included(k),L(k)=struct('startSec',NaN,'endSec',NaN,'nextSec',NaN,'label',scanLabel(d.rawFile,d.label));continue;end
    L(k)=struct('startSec',start,'endSec',start+(d.nFrames-1)*d.TR, ...
        'nextSec',start+d.nFrames*d.TR,'label',scanLabel(d.rawFile,d.label));
    start=L(k).nextSec;
end
end
function [x,y,notes]=sequenceTrace(q,b,c,progress,currentPower)
if nargin<4,progress=@(~,~)[];end
if nargin<5,currentPower=[];end
local=strcmp(q.normMode,'local');
assert(local||fusiBaselineReference('isExternal',b),'deConfUSIon:ScanSequenceBaseline','Select a shared baseline before comparing scans.');
L=sequenceLayout(q);x=[];y=[];notes={};g=struct();
if ~local,r=b.reference;if isfield(r,'sourceGeometry'),g=r.sourceGeometry;end,end
current=q.scans{q.active};chosen=find(includedScans(q));
for slot=1:numel(chosen)
    k=chosen(slot);
    d=q.scans{k};time=(0:d.nFrames-1)*d.TR;values=nan(1,d.nFrames);
    report=@(fraction,message)progress((slot-1+fraction)/numel(chosen), ...
        sprintf('Scan %d/%d: %s | %s',slot,numel(chosen),d.label,message));
    report(0,'Locating this ROI and baseline...');
    try
        roi=mapROI(c,current,d);
        assert(~isempty(roi),'deConfUSIon:ScanSequenceROI','ROI is outside this scan''s physical coverage.');
        if local,placed=localReference(q,d);else,placed=fusiBaselineAlignReference(r,d.spatialSize,g,d.geometry);end
        source=struct('mean',placed.mean,'spatialSize',d.spatialSize,'sourceFile',d.file, ...
            'TR',d.TR,'frames',[1 d.nFrames],'nFrames',d.nFrames,'windowSec',[0 time(end)]);
        power=d.memoryPower;if k==q.active&&~isempty(currentPower),power=currentPower;end
        if ~isempty(power),source.tracePower=power;source.traceFrames=1:d.nFrames;end
        if ~isempty(d.fileInfo),source.fileInfo=d.fileInfo;end
        s=fusiBaselineRoiTrace(source,roi,true,report);values=s.PSC;
    catch ME
        if ~any(strcmp(ME.identifier,{'deConfUSIon:ScanSequenceROI','deConfUSIon:ReferenceTraceROI'})),rethrow(ME);end
        notes{end+1}=[L(k).label ': ' ME.message]; %#ok<AGROW>
    end
    if ~isempty(x),x(end+1)=NaN;y(end+1)=NaN;end %#ok<AGROW>
    x=[x (time+L(k).startSec)/60];y=[y values]; %#ok<AGROW>
    report(1,'Curve ready');
end
progress(1,'ROI time courses ready.');
end
function [proc,b,par,I]=loadScan(q,index,b,par,progress)
if nargin<5,progress=@(~,~)[];end
assert(index>=1&&index<=numel(q.scans),'deConfUSIon:ScanSequenceIndex','Choose a scan from the sequence.');
d=q.scans{index};I=d.memoryPower;
if isempty(I)
    info=fusiBaselineFileInfo(fusiFindMovedDataPath(d.file));
    assert(isequal(info.spatialSize,d.spatialSize)&&info.nFrames==d.nFrames, ...
        'deConfUSIon:ScanSequenceChanged','The selected source dataset changed. Remove it and add it again.');
    if info.partialReadable
        I=zeros(info.size,'single');chunk=max(1,floor(32*1024^2/(4*prod(info.spatialSize))));
        for first=1:chunk:info.nFrames
            last=min(info.nFrames,first+chunk-1);start=ones(size(info.size));count=info.size;
            start(end)=first;count(end)=last-first+1;sub=repmat({':'},1,numel(info.size));sub{end}=first:last;
            progress(.7*(first-1)/info.nFrames,sprintf('Reading %s: frames %d-%d of %d',scanLabel(d.rawFile,d.label),first,last,info.nFrames));
            I(sub{:})=single(h5read(info.file,info.path,start,count));
        end
    elseif ~isempty(info.data),I=info.data;
    else,key=info.path(2:end);s=load(info.file,key);I=s.(key);
    end
end
if strcmp(q.normMode,'local')
    if isfield(b,'reference'),b=rmfield(b,'reference');end
    b.start=q.localWindowSec(1);b.end=q.localWindowSec(2);b.mode='sec';
else
    g=struct();if isfield(b.reference,'sourceGeometry'),g=b.reference.sourceGeometry;end
    b.reference=fusiBaselineAlignReference(b.reference,d.spatialSize,g,d.geometry);
end
if isfield(b,'localBaseline'),b.localBaseline.start=min(b.localBaseline.start,(d.nFrames-2)*d.TR);b.localBaseline.end=min(b.localBaseline.end,(d.nFrames-1)*d.TR);end
par.interpol=1;par.videoInputIsPSC=false;par.baselineRawIsPSC=false;
for name={'fusiAtlasDisplayContext','scmInitialUnderlayInfo','scmPerSliceUnderlayFiles','scmPerSliceUnderlaySourceIdx','scmInitialUnderlayMode','displayDurationSec'}
    if isfield(par,name{1}),par=rmfield(par,name{1});end
end
par.loadedFile=d.rawFile;par.loadedPath=fileparts(d.rawFile);par.activeDataset=d.label;par.datasetTag=d.label;
if isfile(d.rawFile)
    paths=fusiResolveAnalysisFolder(d.rawFile);par.exportPath=paths.datasetFolder;par.selectorRoot=paths.datasetFolder;
    par.registrationPath=fullfile(paths.datasetFolder,'Registration');par.registration2DPath=fullfile(paths.datasetFolder,'Registration2D');
    par.visualizationPath=fullfile(paths.datasetFolder,'Visualization');par.maskStartPath=par.visualizationPath;
    par.underlayStartPath=par.registration2DPath;par.transformStartPath=par.registration2DPath;
end
par.meta=struct('rawMetadata',struct('metadata',d.geometry,'selectedTRUserSec',d.rawTR));
if isfield(d.geometry,'voxelSize'),par.voxelSize=d.geometry.voxelSize;end
par.fusiSequencePowerFile=d.file;q.active=index;par.scanSequence=q;
par.baselineProgressFcn=@(message)progress(.8,message);
progress(.75,'Normalizing selected overlay scan...');
proc=computePSC(I,d.TR,par,b);par=rmfield(par,'baselineProgressFcn');progress(1,'Selected scan ready.');
end
function [q,b]=prepare(q,b,I,TR,par,progress)
if nargin<6,progress=@(~,~)[];end
if ~isfield(q,'normMode'),q.normMode='shared';end
if ~isfield(q,'localReferences'),q.localReferences={};end
if ~isfield(q,'sharedReference'),q.sharedReference=[];end
if ~isfield(q,'localWindowSec')||any(~isfinite(q.localWindowSec))
    source=b;if isfield(b,'localBaseline'),source=b.localBaseline;end
    q.localWindowSec=[source.start source.end];
end
if fusiBaselineReference('isExternal',b),q.sharedReference=b.reference;end
if strcmp(q.normMode,'shared')
    if ~fusiBaselineReference('isExternal',b)&&~isempty(q.sharedReference)
        r=q.sharedReference;g=struct();if isfield(r,'sourceGeometry'),g=r.sourceGeometry;end
        d=q.scans{q.active};b.reference=fusiBaselineAlignReference(r,d.spatialSize,g,d.geometry);
        b.start=r.windowSec(1);b.end=r.windowSec(2);b.mode='sec';
    end
    b=commonBaseline(q,b,I,TR,par);q.sharedReference=b.reference;return;
end
assert(strcmp(q.normMode,'local'),'deConfUSIon:ScanNormalization','Choose shared or per-scan normalization.');
w=q.localWindowSec;
assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>w(1),'deConfUSIon:ScanNormalizationWindow','Enter a positive baseline window in seconds.');
for k=1:numel(q.scans)
    d=q.scans{k};assert(w(2)<=(d.nFrames-1)*d.TR,'deConfUSIon:ScanNormalizationWindow', ...
        '%s lasts %.6g s. Choose a baseline window inside every scan.',d.label,(d.nFrames-1)*d.TR);
end
refs={};
for k=1:numel(q.scans)
    d=q.scans{k};r=[];
    for j=1:numel(q.localReferences)
        old=q.localReferences{j};if strcmp(old.sequenceKey,d.key)&&isequal(old.requestedWindowSec,w)&&old.TR==d.TR,r=old;break;end
    end
    if isempty(r)
        progress((k-1)/numel(q.scans),['Reading per-scan baseline: ' d.label]);
        if ~isempty(d.memoryPower),r=fusiBaselineReference('build',d.memoryPower,d.TR,w);
        else
            info=d.fileInfo;if isempty(info),info=fusiBaselineFileInfo(d.file);end
            r=fusiBaselineReadWindow(info,d.TR,w,struct(), ...
                @(fraction,message)progress((k-1+fraction)/numel(q.scans),message));
        end
        if isfield(r,'tracePower'),r=rmfield(r,{'tracePower','traceFrames'});end
        r.sequenceKey=d.key;
    end
    refs{end+1}=r; %#ok<AGROW>
end
q.localReferences=refs;if isfield(b,'reference'),b=rmfield(b,'reference');end
b.start=w(1);b.end=w(2);b.mode='sec';progress(1,'Per-scan baselines ready.');
end
function r=localReference(q,d)
r=[];
for k=1:numel(q.localReferences)
    if strcmp(q.localReferences{k}.sequenceKey,d.key),r=q.localReferences{k};return;end
end
error('deConfUSIon:ScanNormalization','Prepare the per-scan baseline windows first.');
end
function mapped=mapROI(c,source,target)
[offset,shape]=gridOffset(source,target);
if isfield(c,'roiMaskVolumeIndices')
    [y,x,z]=ind2sub(c.roiMaskSizeYXZ,c.roiMaskVolumeIndices);
else
    b=c.boundsXY;[y,x]=ndgrid(b(3):b(4),b(1):b(2));z=repmat(c.slice,size(y));
    if isfield(c,'roiMaskIndices')
        m=false(c.roiMaskSizeYX);m(c.roiMaskIndices)=true;keep=m(sub2ind(c.roiMaskSizeYX,y,x));y=y(keep);x=x(keep);z=z(keep);
    end
end
p=[y(:) x(:) z(:)]+offset;valid=all(p>=1&p<=shape,2);p=p(valid,:);mapped=[];if isempty(p),return;end
mapped=c;
for name={'roiMaskIndices','roiMaskSizeYX','roiMaskVolumeIndices','roiMaskSizeYXZ'}
    if isfield(mapped,name{1}),mapped=rmfield(mapped,name{1});end
end
mapped.boundsXY=[min(p(:,2)) max(p(:,2)) min(p(:,1)) max(p(:,1))];mapped.slice=round(median(p(:,3)));
mapped.activeSlices=unique(p(:,3))';mapped.roiMaskSizeYXZ=shape;
mapped.roiMaskVolumeIndices=sub2ind(shape,p(:,1),p(:,2),p(:,3));mapped.pixelCount=size(p,1);
if isfield(c,'signalFrames')
    seconds=(double(c.signalFrames)-1)*source.TR;
    mapped.signalFrames=unique(max(1,min(target.nFrames,round(seconds/target.TR)+1)));
end
end
function B=mapVolume(A,source,target)
if isempty(A),B=[];return;end
spatial=source.spatialSize;
if numel(A)~=prod(spatial),B=[];return;end
r=struct('mean',single(reshape(A,spatial)),'spatialSize',spatial);
r=fusiBaselineAlignReference(r,target.spatialSize,source.geometry,target.geometry);B=r.mean;
if islogical(A),B=isfinite(B)&B>0;end
end
function [offset,shape]=gridOffset(source,target)
persistent cache
if isempty(cache),cache={};end
key={source.spatialSize,target.spatialSize,source.geometry,target.geometry};
for k=1:numel(cache),if isequaln(cache{k}.key,key),offset=cache{k}.offset;shape=cache{k}.shape;return;end,end
r=struct('mean',ones(source.spatialSize,'single'),'spatialSize',source.spatialSize);
r=fusiBaselineAlignReference(r,target.spatialSize,source.geometry,target.geometry);
offset=[r.alignment.offsetVoxels zeros(1,3-numel(r.alignment.offsetVoxels))];
shape=[target.spatialSize ones(1,3-numel(target.spatialSize))];
cache{end+1}=struct('key',{key},'offset',offset,'shape',shape);if numel(cache)>24,cache(1)=[];end
end
function included=includedScans(q)
included=cellfun(@(d)~isfield(d,'includeTrace')||logical(d.includeTrace),q.scans);
end
function Y=mapSeries(X,source,target)
[offset,shape]=gridOffset(source,target);native=[source.spatialSize ones(1,3-numel(source.spatialSize))];
if isequal(native,shape)&&all(offset==0),Y=X;return;end
n=size(X,ndims(X));src=cell(1,3);dst=src;
for axis=1:3,src{axis}=max(1,1-offset(axis)):min(native(axis),shape(axis)-offset(axis));dst{axis}=src{axis}+offset(axis);end
Y=nan([shape n],'single');A=reshape(X,[native n]);Y(dst{:},:)=A(src{:},:);
if numel(target.spatialSize)==2,Y=reshape(Y,[shape(1:2) n]);end
end
function q=sortScans(q)
active=q.scans{q.active}.key;times=cellfun(@(d)d.acquiredTime,q.scans);times(~isfinite(times))=inf;
number=inf(size(times));
for k=1:numel(q.scans)
    token=regexp(q.scans{k}.label,'scan(\d+)','tokens','once','ignorecase');if ~isempty(token),number(k)=str2double(token{1});end
end
[~,order]=sortrows([times(:) number(:) (1:numel(times))']);q.scans=q.scans(order);
q.active=find(cellfun(@(d)strcmp(d.key,active),q.scans),1);q.orderMode='time';
end
function t=acquisitionTime(file,g)
t=NaN;
for name={'acquisitionTime','acquisitionDateTime','dateTime','datetime','startTime'}
    if ~isfield(g,name{1}),continue;end
    try
        v=g.(name{1});if ischar(v)||isstring(v)||isa(v,'datetime'),t=datenum(v);
        elseif isnumeric(v)&&isscalar(v)&&v>700000&&v<1000000,t=double(v);end
    catch
    end
    if isfinite(t),return;end
end
if isfile(file),s=dir(file);t=s.datenum;end
end
function g=geometry(g)
if isfield(g,'meta'),g=g.meta;end
if isfield(g,'rawMetadata'),g=g.rawMetadata;end
if isfield(g,'metadata'),g=g.metadata;end
end
function s=scanLabel(file,fallback)
[~,name]=fileparts(file);token=regexp(name,'(?:^|_)(scan\d+(?:_[^.]*)?)$','tokens','once','ignorecase');
if isempty(token),s=fallback;else,s=token{1};end
end
