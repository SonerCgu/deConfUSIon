function [path,options]=fusiChooseAtlasSource(par,root,transformFile,lastFile,dialogs)
% Choose the registration workflow before opening its file/folder picker.
if nargin<5,dialogs=struct();end
if ~isfield(dialogs,'kind'),dialogs.kind=@()questdlg('Choose the atlas source to load.', ...
 'Load atlas','Normal folder','LightSuite folder','Single file','Normal folder');end
if ~isfield(dialogs,'file'),dialogs.file=@uigetfile;end
if ~isfield(dialogs,'folder'),dialogs.folder=@uigetdir;end
if ~isfield(dialogs,'error'),dialogs.error=@(message,title)errordlg(message,title);end
options=fusiUnderlayPickerOptions(par,root,transformFile,lastFile);path='';
kind=dialogs.kind();options.sourceKind=kind;
if strcmp(kind,'Single file')
 [name,folder]=dialogs.file(options.filter,'Load atlas: select Histology, Vascular, Regions or a saved transform',options.defaultFile);
 if isequal(name,0)||isequal(folder,0),return;end
 path=fullfile(folder,name);
elseif strcmp(kind,'LightSuite folder')
 options.startPath=lightSuiteStartPath(root,lastFile,options.startPath);
 options.defaultFile=fullfile(options.startPath,'LightSuite_Native_Regions.mat');
 options.title='Load atlas: choose a LightSuite project folder';
 selected=dialogs.folder(options.startPath,options.title);
 if isequal(selected,0),return;end
 chooser=@listdlg;if isfield(dialogs,'project'),chooser=dialogs.project;end
 selected=fusiLightSuiteChooseAtlasProject(selected,chooser);
 if isempty(selected),return;end
 file=fullfile(char(selected),'LightSuite_Native_Regions.mat');
 if ~isfile(file)
  dialogs.error(['Choose the LightSuite project folder containing LightSuite_Native_Regions.mat. ' ...
   'If it has not been exported yet, open that project in LightSuite and click SAVE / EXPORT BOTH ATLAS STAGES + MASKS.'], ...
   'LightSuite atlas not found');
  return;
 end
 % Route straight to native underlays, bypassing normal atlas discovery.
 options.startPath=char(selected);options.defaultFile=file;
 path=file;
elseif any(strcmp(kind,{'Normal folder','Folder'}))
 options.title='Load atlas: choose a normal registration or atlas folder';
 selected=dialogs.folder(options.startPath,options.title);
 if isequal(selected,0),return;end
 path=char(selected);
end
end

function folder=lightSuiteStartPath(root,lastFile,fallback)
% Check only the remembered project and known locations in this recording.
folder=fallback;candidates={};
if ~isempty(lastFile)
 if isfolder(lastFile),candidates{end+1}=char(lastFile);
 elseif isfile(lastFile),candidates{end+1}=fileparts(char(lastFile));end
end
recording=fusiModelAnalysisFolder(struct('exportPath',root));
for base={recording,fallback}
 candidates=[candidates {fullfile(base{1},'Registration','LightSuite'), ...
  fullfile(base{1},'Registration3D','LightSuite'),fullfile(base{1},'LightSuite'),base{1}}]; %#ok<AGROW>
end
for k=1:numel(candidates)
 if isfile(fullfile(candidates{k},'LightSuite_Native_Regions.mat'))|| ...
    isfile(fullfile(candidates{k},'deconfusion_lightsuite_session.mat'))
  folder=candidates{k};return;
 end
end
end
