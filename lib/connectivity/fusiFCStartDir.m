function folder=fusiFCStartDir(subj,opts)
% Use the same recording-aware atlas resolver as SCM and Video.
root=pwd;if isfield(subj,'analysisDir')&&isfolder(subj.analysisDir),root=subj.analysisDir;
elseif isfield(opts,'exportPath')&&isfolder(opts.exportPath),root=opts.exportPath;
elseif isfield(opts,'saveRoot')&&isfolder(opts.saveRoot),root=opts.saveRoot;end
par=opts;par.exportPath=root;par.selectorRoot=root;
if isfield(subj,'sourceFile')&&isfile(subj.sourceFile)
 par.loadedFile=subj.sourceFile;
 [~,stem]=fileparts(subj.sourceFile);
 if ~isempty(regexp(stem,'_scan\d+','once'))
  d=struct('rawFile',subj.sourceFile,'file','','key',subj.sourceFile,'label',stem);
  par.scanSequence=struct('scans',{{d}},'active',1,'originalKey',d.key,'shareAtlasMapping',true);
 end
end
if isfield(subj,'atlasSourceFile')&&isfile(subj.atlasSourceFile),folder=fileparts(subj.atlasSourceFile);return;end
if size(subj.I4,3)>1
 par.registrationPath=fullfile(root,'Registration');par.registration3DPath=fullfile(root,'Registration3D');
 if isfield(par,'registration2DPath'),par=rmfield(par,'registration2DPath');end
 if isfield(par,'startDirAtlas')&&contains(lower(par.startDirAtlas),'registration2d'),par=rmfield(par,'startDirAtlas');end
end
p=fusiUnderlayPickerOptions(par,root);folder=p.startPath;
if ~isfolder(folder),folder=root;end
end
