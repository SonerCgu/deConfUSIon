function folder=fusiAtlasTransformFolder(par,transformFile,rememberFolder,forSave)
% Remember transform location per recording folder, never across animals.
if nargin<2,transformFile='';end
if nargin<4,forSave=false;end
root='';
for field={'loadedPath','loadedFile','sourceFile','visualizationPath'}
    if ~isfield(par,field{1}) || isempty(par.(field{1})),continue;end
    candidate=char(par.(field{1}));
    if isfile(candidate),candidate=fileparts(candidate);end
    if isfolder(candidate),root=candidate;break;end
end
if isempty(root),root=pwd;end
key=lower(strrep(root,'\','/'));
locations=getpref('deConfUSIon','atlasTransformLocations',struct('animal',{},'folder',{}));
idx=find(strcmp({locations.animal},key),1);
if nargin>=3 && ~isempty(rememberFolder) && isfolder(rememberFolder)
    if isempty(idx),idx=numel(locations)+1;end
    locations(idx)=struct('animal',key,'folder',char(rememberFolder));
    setpref('deConfUSIon','atlasTransformLocations',locations);
end
if forSave
 if ~isempty(transformFile) && isfile(transformFile)
  oldFolder=fileparts(transformFile);folder=fusiAnalysisOutputPath(oldFolder);
  if ~strcmp(folder,oldFolder),folder=fullfile(fusiModelAnalysisFolder(par),'Registration3D');end
  return;
 end
 if ~isempty(idx) && isfolder(locations(idx).folder)
  oldFolder=locations(idx).folder;folder=fusiAnalysisOutputPath(oldFolder);
  if ~strcmp(folder,oldFolder),folder=fullfile(fusiModelAnalysisFolder(par),'Registration3D');end
  return;
 end
 folder=fullfile(fusiModelAnalysisFolder(par),'Registration3D');return;
end
if ~isempty(transformFile) && isfile(transformFile),folder=fileparts(transformFile);return;end
if ~isempty(idx) && isfolder(locations(idx).folder),folder=locations(idx).folder;return;end
candidates={fullfile(root,'Registration3D'),root};
if isfield(par,'visualizationPath') && isfolder(par.visualizationPath)
    candidates=[{fullfile(char(par.visualizationPath),'Registration3D'),char(par.visualizationPath)} candidates];
end
for k=1:numel(candidates)
    if isfile(fullfile(candidates{k},'Transformation.mat')),folder=candidates{k};return;end
end
folder=fullfile(root,'Registration3D');
if ~isfolder(folder) && ~forSave,folder=root;end
end
