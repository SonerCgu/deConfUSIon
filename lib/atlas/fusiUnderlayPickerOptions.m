function options=fusiUnderlayPickerOptions(par,root,transformFile,lastFile)
% Find this recording's saved underlays without scanning other animals.
if nargin<1 || isempty(par),par=struct();end
if nargin<2 || isempty(root),root=pwd;end
if nargin<3,transformFile='';end
if nargin<4,lastFile='';end
% Overlay selection owns the picker location. A retained atlas may belong
% to another scan; it must not hide the newly selected scan's registration.
if isfield(par,'scanSequence')&&~isempty(par.scanSequence.scans)
 q=par.scanSequence;active=q.active;
 [scanPar,scanRoot]=scanPaths(q.scans{active},par,root);
 options=recordingOptions(scanPar,scanRoot,'','');
 if hasRegistration(options.startPath),annotate(q.scans{active},false);return;end
 if fusiScanSequence('shareAtlas',q)
  remembered=recordingOptions(scanPar,scanRoot,transformFile,lastFile);
  if hasRegistration(remembered.startPath)
   options=remembered;
   for index=1:numel(q.scans)
    [~,ownerRoot]=scanPaths(q.scans{index},par,root);
    if startsWith(lower(strrep(options.startPath,'\','/')),[lower(strrep(ownerRoot,'\','/')) '/'])
     annotate(q.scans{index},index~=active);return;
    end
   end
   options.title='Retained shared atlas: select Histology, Vascular or Regions';return;
  end
  original=find(cellfun(@(d)strcmp(d.key,q.originalKey),q.scans),1);
  indices=unique([original 1:numel(q.scans)],'stable');
  for index=indices
   if index==active,continue;end
   [otherPar,otherRoot]=scanPaths(q.scans{index},par,root);
   other=recordingOptions(otherPar,otherRoot,'','');
   if hasRegistration(other.startPath),options=other;annotate(q.scans{index},true);return;end
  end
  % A saved sibling scan need not be loaded just to choose its anatomy.
  % Inspect only matching scan folders of this animal, with a real raw file.
  d=q.scans{active};[rawFolder,stem]=fileparts(d.rawFile);
  prefix=regexprep(stem,'_scan\d+.*$','','ignorecase');
  if ~strcmp(prefix,stem)
   siblings=dir(fullfile(fileparts(scanRoot),[prefix '_scan*']));siblings=siblings([siblings.isdir]);
   for entry=reshape(siblings,1,[])
    raw=fullfile(rawFolder,[entry.name '.mat']);if ~isfile(raw),continue;end
    source=struct('rawFile',raw,'file','','key',raw,'label',entry.name);
    [otherPar,otherRoot]=scanPaths(source,par,root);other=recordingOptions(otherPar,otherRoot,'','');
    if hasRegistration(other.startPath),options=other;annotate(source,true);return;end
   end
  end
 end
 return;
end
options=recordingOptions(par,root,transformFile,lastFile);
 function annotate(d,shared)
  options.sourceScanKey=d.key;options.sourceScanLabel=d.label;options.sharedFromAnotherScan=shared;
  options.sourceScanLoaded=any(cellfun(@(scan)strcmp(scan.rawFile,d.rawFile),q.scans));
  [~,stem]=fileparts(d.rawFile);short=regexp(stem,'(?:^|_)(scan\d+.*)$','tokens','once','ignorecase');
  if isempty(short),short={d.label};end
  if shared,options.title=sprintf('Shared atlas from %s: select Histology, Vascular or Regions',short{1});
  else,options.title=sprintf('Atlas for %s: select Histology, Vascular or Regions',short{1});end
 end
end
function [par,root]=scanPaths(d,fallback,root)
% Rebuild from the active descriptor, without stale original-scan hints.
par=struct();raw=fusiFindMovedDataPath(d.rawFile);
if ~isempty(raw)&&isfile(raw)
 paths=fusiResolveAnalysisFolder(raw);root=paths.datasetFolder;
 par=struct('loadedFile',raw,'loadedPath',root,'rawPath',fileparts(raw),'exportPath',root,'selectorRoot',root, ...
  'registrationPath',fullfile(root,'Registration'),'registration3DPath',fullfile(root,'Registration3D'), ...
  'underlayStartPath',fullfile(root,'Registration2D'),'visualizationPath',fullfile(root,'Visualization'));
elseif ~isempty(d.file)&&isfile(d.file)
 root=datasetRoot(fileparts(d.file));par=struct('loadedFile',d.file,'exportPath',root,'selectorRoot',root);
else,par=fallback;
end
end
function yes=hasRegistration(folder)
yes=isBundle(folder);
if ~yes&&isfolder(folder)
 files=dir(fullfile(folder,'*.mat'));yes=any([files.bytes]>0);
end
end
function options=recordingOptions(par,root,transformFile,lastFile)
filters={'*.mat','MATLAB / atlas underlays (*.mat)'; ...
 '*.mat;*.nii;*.nii.gz;*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp','All supported underlays'; ...
 '*.nii;*.nii.gz','NIfTI underlays (*.nii, *.nii.gz)'; ...
 '*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp','Image underlays'; ...
 '*.*','All files (*.*)'};
options=struct('filter', {filters},'title','Select underlay: Histology, Vascular, Regions or another image', ...
 'startPath','','defaultFile','');
% Motor sessions have one combined AtlasUnderlays folder beside the index.
for selected={lastFile,transformFile}
 path=selected{1};if isempty(path),continue;end
 if isfolder(path)
  if isfile(fullfile(path,'StepMotor_Reg2D_Session.mat'))&&isBundle(fullfile(path,'AtlasUnderlays'))
   finish(fullfile(path,'AtlasUnderlays'));return;
  elseif isBundle(path),finish(path);return;end
 elseif isfile(path)
  parent=fileparts(path);
  if isfile(fullfile(parent,'StepMotor_Reg2D_Session.mat'))&&isBundle(fullfile(parent,'AtlasUnderlays'))
   finish(fullfile(parent,'AtlasUnderlays'));return;
  end
 end
end
if ~isempty(lastFile) && isfile(lastFile),finish(fileparts(lastFile));return;end
if ~isempty(transformFile) && isfile(transformFile)
 folder=fileparts(transformFile);
 if isBundle(folder),finish(folder);return;end
 % Only read the small transform metadata, never the anatomical arrays.
 try
  S=load(transformFile,'Transf');
  if isfield(S,'Transf') && isfield(S.Transf,'atlasUnderlays') && ...
    isfield(S.Transf.atlasUnderlays,'folder') && isBundle(S.Transf.atlasUnderlays.folder)
   finish(S.Transf.atlasUnderlays.folder);return;
  end
 catch
 end
end
roots={root};configured='';
for field={'underlayStartPath','transformStartPath','registrationPath','registration3DPath', ...
 'selectorRoot','exportPath','loadedPath','rawPath','loadedFile','sourceFile','visualizationPath'}
 if ~isfield(par,field{1}) || isempty(par.(field{1})),continue;end
 path=char(par.(field{1}));if isfile(path),path=fileparts(path);end
 if isfolder(path)
  roots{end+1}=path;roots{end+1}=datasetRoot(path); %#ok<AGROW>
  if strcmp(field{1},'underlayStartPath'),configured=path;end
 end
end
if isBundle(configured),finish(configured);return;end
% The transform helper falls back to pwd without source metadata. Do not
% import a remembered unrelated recording when this selector has only a root.
for field={'loadedPath','loadedFile','sourceFile','visualizationPath'}
 if isfield(par,field{1}) && ~isempty(par.(field{1}))
  try,roots{end+1}=fusiAtlasTransformFolder(par);catch,end
  break;
 end
end
try,roots{end+1}=fusiModelAnalysisFolder(par);catch,end
if ~isempty(transformFile),roots{end+1}=fileparts(transformFile);end
roots=[roots cellfun(@fusiAnalysisOutputPath,roots,'UniformOutput',false)];
roots=unique(roots,'stable');parents={};
for k=1:numel(roots)
 path=roots{k};
 if isBundle(path),finish(path);return;end
 if isBundle(fullfile(path,'AtlasUnderlays')),finish(fullfile(path,'AtlasUnderlays'));return;end
 parents=[parents {path,fullfile(path,'AtlasUnderlays3D'), ...
  fullfile(path,'Registration','AtlasUnderlays3D'),fullfile(path,'Registration3D','AtlasUnderlays3D'), ...
  fullfile(path,'Visualization','Registration3D','AtlasUnderlays3D'), ...
  fullfile(path,'Visualization','Registration','AtlasUnderlays3D')}]; %#ok<AGROW>
end
parents=unique(parents,'stable');found={};times=[];
% Each user save now owns a dated registration directory. Search just these
% known children of this recording; never scan unrelated animals recursively.
registrationRoots=unique([roots cellfun(@(p)fullfile(p,'Registration'),roots,'UniformOutput',false) ...
 cellfun(@(p)fullfile(p,'Registration3D'),roots,'UniformOutput',false) ...
 cellfun(@(p)fullfile(p,'Visualization','Registration3D'),roots,'UniformOutput',false)],'stable');
for k=1:numel(registrationRoots)
 runs=dir(fullfile(registrationRoots{k},'AtlasRegistration_*'));runs=runs([runs.isdir]);
 for j=1:numel(runs)
  run=fullfile(runs(j).folder,runs(j).name);
  if isBundle(fullfile(run,'AtlasUnderlays')),finish(fullfile(run,'AtlasUnderlays'));return;end
  parents{end+1}=fullfile(run,'AtlasUnderlays3D'); %#ok<AGROW>
 end
end
parents=unique(parents,'stable');
for k=1:numel(parents)
 parent=parents{k};[~,leaf]=fileparts(parent);
 if ~strcmpi(leaf,'AtlasUnderlays3D') || ~isfolder(parent),continue;end
 entries=dir(parent);entries=entries([entries.isdir] & ~ismember({entries.name},{'.','..'}));
 for j=1:numel(entries)
  folder=fullfile(parent,entries(j).name);
  if isBundle(folder),found{end+1}=folder;times(end+1)=entries(j).datenum;end %#ok<AGROW>
 end
end
if ~isempty(found),[~,latest]=max(times);finish(found{latest});return;end
% Preserve the established 2D / Mask Editor route when no 3D bundle exists.
candidates={configured};
if ~isempty(transformFile),candidates{end+1}=fileparts(transformFile);end
candidates=[candidates {fullfile(root,'Registration2D'),fullfile(root,'Registration'), ...
 fullfile(root,'Registration3D'),fullfile(root,'Visualization'),root,pwd}];
% Empty preset directories must not hide a saved 2D registration elsewhere
% in this recording. Still retain that preset if there are no saved files.
for k=1:numel(candidates)
 if ~isempty(candidates{k})&&isfolder(candidates{k})&&~strcmpi(candidates{k},pwd)&&hasRegistration(candidates{k})
  finish(candidates{k});return;
 end
end
for k=1:numel(candidates),if isfolder(candidates{k}),finish(candidates{k});return;end,end
finish(pwd);
 function finish(folder)
  options.startPath=char(folder);options.defaultFile=fullfile(options.startPath,'*.mat');
 end
end
function yes=isBundle(folder)
yes=~isempty(folder) && isfolder(folder) && ...
 (isfile(fullfile(folder,'Histology.mat')) || isfile(fullfile(folder,'Vascular.mat')) || isfile(fullfile(folder,'Regions.mat')));
end
function root=datasetRoot(root)
% A dated bundle, registration folder or visualization folder is a child.
while true
 [parent,leaf]=fileparts(root);[~,parentLeaf]=fileparts(parent);
 if startsWith(leaf,'AtlasRegistration_') || strcmpi(parentLeaf,'AtlasUnderlays3D') || any(strcmpi(leaf, ...
   {'AtlasUnderlays3D','Registration3D','Registration2D','Registration','Visualization','Preprocessing','PSC'}))
  root=parent;
 else,return;end
 if isempty(parent),return;end
end
end
