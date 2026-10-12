function [path,options]=fusiChooseAtlasSource(par,root,transformFile,lastFile,dialogs)
% Classic MATLAB requires separate file/folder pickers; choose the kind once.
if nargin<5,dialogs=struct();end
if ~isfield(dialogs,'kind'),dialogs.kind=@()questdlg('Load a single saved atlas file or an atlas/session folder?', ...
 'Load atlas','Single file','Folder','Cancel','Single file');end
if ~isfield(dialogs,'file'),dialogs.file=@uigetfile;end
if ~isfield(dialogs,'folder'),dialogs.folder=@uigetdir;end
options=fusiUnderlayPickerOptions(par,root,transformFile,lastFile);path='';
kind=dialogs.kind();options.sourceKind=kind;
if strcmp(kind,'Single file')
 [name,folder]=dialogs.file(options.filter,'Load atlas: select Histology, Vascular, Regions or a saved transform',options.defaultFile);
 if isequal(name,0)||isequal(folder,0),return;end
 path=fullfile(folder,name);
elseif strcmp(kind,'Folder')
 selected=dialogs.folder(options.startPath,'Load atlas: choose a saved registration or atlas/session folder');
 if isequal(selected,0),return;end
 path=char(selected);
end
end
