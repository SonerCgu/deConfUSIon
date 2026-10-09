function [file,options]=fusiChooseAtlasTransformFile(par,root,currentFile,lastUnderlay,dialogFcn)
% Explicit selection, starting at this recording's paired/last transform.
if nargin<5||isempty(dialogFcn),dialogFcn=@uigetfile;end
initial='';
for candidate={currentFile,lastUnderlay}
 path=char(candidate{1});if isempty(path)||~isfile(path),continue;end
 try
  contents=whos('-file',path);headers=intersect({'Transf','atlasUnderlayMeta'},{contents.name});
  if isempty(headers),continue;end
  S=load(path,headers{:});
  if isfield(S,'atlasUnderlayMeta')&&isfield(S,'Transf')
   meta=struct('transform',S.Transf,'transformFile',S.atlasUnderlayMeta.transformFile);
   initial=fusiAtlasPairedTransformFile(meta,path);
  elseif isfield(S,'Transf'),initial=path;
  end
 catch
 end
 if ~isempty(initial),break;end
end
if isempty(initial)
 underlay=fusiUnderlayPickerOptions(par,root,currentFile,lastUnderlay);
 initial=fullfile(underlay.startPath,'Transformation.mat');
 if ~isfile(initial),initial=fullfile(underlay.startPath,'*.mat');end
end
options=struct('filter',{{'*.mat','Atlas transformations (*.mat)'}}, ...
 'title','Choose the atlas transform to apply to the original functional data', ...
 'defaultFile',initial,'startPath',fileparts(initial));
[name,folder]=dialogFcn(options.filter,options.title,options.defaultFile);
file='';if isequal(name,0)||isequal(folder,0),return;end
file=fullfile(folder,name);
end
