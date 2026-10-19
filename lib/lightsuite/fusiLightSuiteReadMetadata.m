function meta=fusiLightSuiteReadMetadata(filename,seed,visited)
% Read geometry fields, including headers nested inside saved datasets.
% v7.3 structs are inspected through HDF5 so newData.I is never loaded here.
if nargin<2||~isstruct(seed),seed=struct();end
if nargin<3,visited={};end
meta=seed;
if isempty(filename)||~isfile(filename)||numel(visited)>=4,return;end
[~,attr]=fileattrib(filename);filename=attr.Name;
if any(strcmpi(visited,filename)),return;end
visited{end+1}=filename;
if endsWith(filename,{'.nii','.nii.gz'},'IgnoreCase',true)
    info=niftiinfo(filename);meta=struct('nifti',info, ...
        'voxelSize',double(info.PixelDimensions(1:3)),'voxelSizeUnit',info.SpaceUnits, ...
        'lightSuiteInputSize',double(info.ImageSize));return;
end
if ~endsWith(filename,'.mat','IgnoreCase',true),return;end
W=whos('-file',filename);header=struct();
if H5F.is_hdf5(filename)
    header=readGroup(filename,'/',0);
else
    % Classic MAT cannot read one field of a large struct. Support small
    % legacy datasets without loading an unbounded movie just for this UI.
    found=ismember({W.name},headerFields())&[W.bytes]<=8*1024^2;
    if any(found),header=geometryOnly(load(filename,W(found).name),0);end
end
shape=recordingSize(filename,W);
if ~isempty(shape),header.lightSuiteInputSize=shape;end
% A selected file owns its geometry, even when its header has no known units.
if ~isempty(fieldnames(header)),meta=header;end
[mm,why]=fusiLightSuiteSpacing(meta);
if ~isempty(mm)||contains(why,'permuted'),return;end
% Older processing saves copied voxelSize without units. Recover the original
% header through saved provenance only when the spatial grid still matches.
if numel(shape)<3,return;end
paths=sourcePaths(header,fileparts(filename));
for k=1:numel(paths)
    try,original=fusiLightSuiteReadMetadata(paths{k},struct(),visited);catch,continue;end
    if ~isfield(original,'lightSuiteInputSize'),continue;end
    sz=original.lightSuiteInputSize;
    if numel(sz)<3||~isequal(double(shape(1:3)),double(sz(1:3))),continue;end
    [mm,why]=fusiLightSuiteSpacing(original);
    if isempty(mm),continue;end
    values=spacingValues(header);sourceValues=spacingValues(original);
    if ~isempty(values)&&~all(cellfun(@(v)any(cellfun(@(x)all(abs(v-x)<=max(1e-9,abs(x)*1e-6)),sourceValues)),values)),continue;end
    meta.voxelSizeMm=mm;
    meta.spacingProvenance=['Original recording header (matching spatial grid): ' paths{k} '. ' why];
    return;
end
end

function fields=headerFields()
fields={'rawMetadata','metadata','md','meta','newData','data','D','par','loadedPar', ...
    'voxelSize','voxelSizeMm','voxelSizeUm','voxelSizeUnit','voxelSizeUnits', ...
    'spatialUnits','SpaceUnits','imageDim','imageSize','imageType','origin','origen', ...
    'inputIsPSC','nifti','PixelDimensions','permuteApplied','axisPermutation', ...
    'sourceFile','sourcePath','sourceFileName','lightSuiteInputSize'};
end

function result=geometryOnly(s,depth)
result=struct();if ~isstruct(s)||~isscalar(s)||depth>10,return;end
keys=intersect(headerFields(),fieldnames(s),'stable');
for k=1:numel(keys)
    key=keys{k};value=s.(key);
    if isstruct(value),result.(key)=geometryOnly(value,depth+1);
    elseif (isnumeric(value)||islogical(value)||ischar(value)||isstring(value))&&numel(value)<=4096
        result.(key)=value;
    end
end
end

function result=readGroup(file,path,depth)
result=struct();if depth>10,return;end
info=h5info(file,path);fields=headerFields();
for k=1:numel(info.Groups)
    group=info.Groups(k);[~,key]=fileparts(group.Name);
    if ismember(key,fields),result.(key)=readGroup(file,group.Name,depth+1);end
end
for k=1:numel(info.Datasets)
    item=info.Datasets(k);key=item.Name;
    if ~ismember(key,fields)||prod(double(item.Dataspace.Size))>4096,continue;end
    full=[strip(path,'right','/') '/' key];
    try
        cls=char(h5readatt(file,full,'MATLAB_class'));
        if ~ismember(cls,{'char','double','single','logical','int8','uint8','int16','uint16','int32','uint32','int64','uint64'}),continue;end
        if any(strcmp({item.Attributes.Name},'MATLAB_empty')),continue;end
        value=h5read(file,full);
        if strcmp(cls,'char'),value=char(value);elseif strcmp(cls,'logical'),value=logical(value);end
        result.(key)=value;
    catch
        % Unsupported reference/cell/string fields are not geometry headers.
    end
end
end

function shape=recordingSize(file,W)
shape=[];
for key={'I','IQR','img','image','volume','newData','data','D'}
    j=find(strcmp({W.name},key{1}),1);if isempty(j),continue;end
    if strcmp(W(j).class,'struct')
        if ~H5F.is_hdf5(file),continue;end
        try,h=h5info(file,['/' key{1} '/I']);shape=double(h.Dataspace.Size);catch,continue;end
    else,shape=double(W(j).size);
    end
    if numel(shape)>=3,return;end
    shape=[];
end
end

function paths=sourcePaths(s,folder)
paths={};if ~isstruct(s)||~isscalar(s),return;end
if isfield(s,'sourceFile')&&ischar(s.sourceFile),paths{end+1}=s.sourceFile;end
if isfield(s,'sourcePath')&&isfield(s,'sourceFileName')&&ischar(s.sourcePath)&&ischar(s.sourceFileName)
    paths{end+1}=fullfile(s.sourcePath,s.sourceFileName);
end
for key={'newData','data','D','par','meta','metadata','rawMetadata'}
    if isfield(s,key{1}),paths=[paths sourcePaths(s.(key{1}),folder)];end %#ok<AGROW>
end
for k=1:numel(paths)
    if ~isfile(paths{k})&&isfile(fullfile(folder,paths{k})),paths{k}=fullfile(folder,paths{k});end
end
paths=unique(paths,'stable');
end

function values=spacingValues(s)
values={};if ~isstruct(s)||~isscalar(s),return;end
if isfield(s,'voxelSize')&&isnumeric(s.voxelSize)&&numel(s.voxelSize)==3
    values={double(s.voxelSize(:)')};return;
end
for key={'newData','data','D','par','meta','metadata','md','rawMetadata'}
    if isfield(s,key{1}),values=[values spacingValues(s.(key{1}))];end %#ok<AGROW>
end
end
