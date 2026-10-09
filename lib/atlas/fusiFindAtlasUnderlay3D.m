function bundle=fusiFindAtlasUnderlay3D(par,root,transformFile,lastFile,shape)
% The explicitly selected underlay carries its own exact 3D affine.
bundle=[];options=fusiUnderlayPickerOptions(par,root,transformFile,lastFile);
% An explicit file is authoritative. Never replace a failed/old selected
% transform with a newer discovered bundle just because dimensions match.
if ~isempty(transformFile)
 bundle=fromExplicitFile(transformFile,lastFile,shape);return;
end
files={transformFile,lastFile,fullfile(options.startPath,'Histology.mat'), ...
 fullfile(options.startPath,'Vascular.mat'),fullfile(options.startPath,'Regions.mat')};
folders={root,fullfile(root,'Registration3D'),fullfile(root,'Registration')};
for field={'loadedPath','rawPath','exportPath','registrationPath','registration3DPath'}
 if isfield(par,field{1}) && ~isempty(par.(field{1}))
  folder=char(par.(field{1}));if isfile(folder),folder=fileparts(folder);end
  folders=[folders {folder,fullfile(folder,'Registration3D'),fullfile(folder,'Registration')}]; %#ok<AGROW>
 end
end
for field={'loadedPath','loadedFile','sourceFile','visualizationPath'}
 if isfield(par,field{1}) && ~isempty(par.(field{1}))
  try,folders{end+1}=fusiAtlasTransformFolder(par);catch,end
  break;
 end
end
for k=1:numel(folders),files{end+1}=fullfile(folders{k},'Transformation.mat');end
canonical=[];mainFile='';
for k=1:numel(files)
 file=files{k};if isempty(file) || ~isfile(file),continue;end
 try,S=load(file);[matched,U,meta]=fusiReadAtlasUnderlay3D(S);catch,continue;end
 if ~matched
  if isempty(canonical) && isfield(S,'Transf') && isfield(S.Transf,'M') && ...
    isfield(S.Transf,'size') && isfield(S.Transf,'scanGeometry') && ...
    isequal(size(S.Transf.M),[4 4]) && ...
    isfield(S.Transf.scanGeometry,'convention') && strcmp(S.Transf.scanGeometry.convention,'coronal_stack_v2') && ...
    isequal(double(S.Transf.scanGeometry.originalSize),double(shape))
   canonical=S.Transf;mainFile=file;
  end
  continue;
 end
 if ~matched || ~isstruct(meta.transform.scanGeometry),continue;end
 if ~isequal(double(meta.transform.scanGeometry.originalSize),double(shape)),continue;end
 if ~isempty(canonical) && (~isequal(meta.transform.M,canonical.M) || ...
   ~isequal(meta.transform.scanGeometry,canonical.scanGeometry)),continue;end
 bundle=struct('file',file,'underlay',U,'meta',meta);return;
end
% Older saves can contain the affine without a linked underlay bundle.
% Use only an atlas whose grid matches the saved transform exactly.
if isempty(canonical),return;end
atlasFile=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');
if isfield(canonical,'atlasSource') && isfile(canonical.atlasSource),atlasFile=canonical.atlasSource;end
contents=whos('-file',atlasFile);
if ismember('atlas',{contents.name}),A=load(atlasFile,'atlas');A=A.atlas;
else,A=load(atlasFile,'Histology');end
assert(isfield(A,'Histology') && isequal(double(size(A.Histology)),double(canonical.size)), ...
 'deConfUSIon:AtlasUnderlayGrid','The saved 3D transform needs its matching atlas reference.');
canonical.displayPermutation=[2 3 1];canonical.atlasCanonicalSize=canonical.size;
canonical.outputSize=canonical.size([2 3 1]);
S=struct('Transf',canonical,'atlasMode','histology','atlasUnderlay',permute(A.Histology,[2 3 1]), ...
 'atlasUnderlayMeta',struct('kind','deConfUSIon_3D_registration_underlay','arrayOrder','DV-LR-AP', ...
 'voxelSizeUm',canonical.scanGeometry.atlasVoxelSizeUm([2 3 1]),'transformFile',mainFile));
[~,U,meta]=fusiReadAtlasUnderlay3D(S);bundle=struct('file',mainFile,'underlay',U,'meta',meta);
end

function bundle=fromExplicitFile(file,lastFile,shape)
bundle=[];if ~isfile(file),return;end
S=load(file);[matched,U,meta]=fusiReadAtlasUnderlay3D(S);
if matched
 if ~isequal(double(meta.transform.scanGeometry.originalSize),double(shape)),return;end
 meta.selectedTransformFile=file;
 bundle=struct('file',file,'underlay',U,'meta',meta);return;
end
if ~isfield(S,'Transf'),return;end
T=S.Transf;
if ~isfield(T,'scanGeometry')||~isfield(T.scanGeometry,'convention')|| ...
 ~strcmp(T.scanGeometry.convention,'coronal_stack_v2')|| ...
 ~isequal(double(T.scanGeometry.originalSize),double(shape)),return;end
fusiAtlasRecordingGrid3D(T); % Reject invalid/reflected geometry explicitly.
files={lastFile};
if isfield(T,'atlasUnderlays')
 for field={'histology','vascular','regions'}
  if isfield(T.atlasUnderlays,field{1}),files{end+1}=T.atlasUnderlays.(field{1});end %#ok<AGROW>
 end
end
files=[files {fullfile(fileparts(file),'Histology.mat'),fullfile(fileparts(file),'Vascular.mat')}];
for k=1:numel(files)
 candidate=files{k};if isempty(candidate)||~isfile(candidate),continue;end
 [matched,U,meta]=fusiCachedAtlasUnderlay3D(candidate);
 if matched&&isequaln(meta.transform.M,T.M)&&isequaln(meta.transform.scanGeometry,T.scanGeometry)
  meta.transformFile=file;meta.selectedTransformFile=file;
  bundle=struct('file',candidate,'underlay',U,'meta',meta);return;
 end
end
% Legacy transform files may not carry a companion folder. Reconstruct only
% their own exact atlas reference, without using another discovered affine.
atlasFile=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');
if isfield(T,'atlasSource')&&isfile(T.atlasSource),atlasFile=T.atlasSource;end
contents=whos('-file',atlasFile);
if ismember('atlas',{contents.name}),A=load(atlasFile,'atlas');A=A.atlas;
else,A=load(atlasFile,'Histology');end
assert(isfield(A,'Histology')&&isequal(double(size(A.Histology)),double(T.size)), ...
 'deConfUSIon:AtlasUnderlayGrid','The selected transform needs its matching atlas reference.');
T.displayPermutation=[2 3 1];T.atlasCanonicalSize=T.size;T.outputSize=T.size([2 3 1]);
payload=struct('Transf',T,'atlasMode','histology','atlasUnderlay',permute(A.Histology,[2 3 1]), ...
 'atlasUnderlayMeta',struct('kind','deConfUSIon_3D_registration_underlay','arrayOrder','DV-LR-AP', ...
 'voxelSizeUm',T.scanGeometry.atlasVoxelSizeUm([2 3 1]),'transformFile',file));
[~,U,meta]=fusiReadAtlasUnderlay3D(payload);meta.selectedTransformFile=file;
bundle=struct('file',file,'underlay',U,'meta',meta);
end
