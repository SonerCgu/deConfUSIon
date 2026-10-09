function bundle=fusiReadStepMotorUnderlays2D(path)
% Resolve only the explicitly selected motor session; never mix save dates.
bundle=[];path=char(path);selectedName='Histology';
if isfolder(path)
 [parent,leaf]=fileparts(path);if strcmpi(leaf,'AtlasUnderlays'),path=parent;end
 sessionFile=fullfile(path,'StepMotor_Reg2D_Session.mat');
 if ~isfile(sessionFile),return;end
elseif isfile(path)
 [~,~,extension]=fileparts(path);if ~strcmpi(extension,'.mat'),return;end
 vars=whos('-file',path);names={vars.name};
 if ismember('stepMotorUnderlayMeta',names)
  S=load(path,'stepMotorUnderlayMeta');meta=S.stepMotorUnderlayMeta;
  if ~strcmp(meta.kind,'deConfUSIon_step_motor_registration_underlay'),return;end
  sessionFile=fullfile(fileparts(path),meta.sessionFileRelative);selectedName=meta.choiceName;
 elseif ismember('StepMotorReg2D',names),sessionFile=path;
 else,return;end
else,return;end
assert(isfile(sessionFile),'deConfUSIon:StepMotorSessionMissing','The selected underlay has no paired step-motor session. Keep the session and its subfolders together.');
S=load(sessionFile,'StepMotorReg2D');session=S.StepMotorReg2D;
assert(all(isfield(session,{'files','Reg2DList','sourceNSlices','savedSourceIdx'})), ...
 'deConfUSIon:StepMotorSessionInvalid','The step-motor session has incomplete slice mappings.');
folder=fileparts(sessionFile);files=session.files;
if isfield(session,'filesRelative')
 files=cellfun(@(f)fullfile(folder,f),session.filesRelative,'UniformOutput',false);
end
assert(numel(files)==numel(session.savedSourceIdx)&&numel(files)==numel(session.Reg2DList), ...
 'deConfUSIon:StepMotorSliceMapping','Session transform count and source-slice mappings disagree.');
indices=double(session.savedSourceIdx(:)');
assert(all(isfinite(indices)&indices>=1&indices<=session.sourceNSlices&indices==round(indices))&&numel(unique(indices))==numel(indices), ...
 'deConfUSIon:StepMotorSliceMapping','Saved source-slice indices are invalid or repeated.');
[indices,order]=sort(indices);files=files(order);
regList=struct('sourceIdx',{},'file',{},'T',{},'score',{});
for k=1:numel(files)
 assert(isfile(files{k}),'deConfUSIon:StepMotorTransformMissing','Missing saved motor transform: %s',files{k});
 P=load(files{k},'Reg2D');r=P.Reg2D;
 assert(strcmp(r.type,'simple_coronal_2d')&&r.sourceSliceIndex==indices(k), ...
  'deConfUSIon:StepMotorSliceMapping','The transform source-slice index differs from its session mapping.');
 T=r;T.warpA=r.A;T.outSize=double(r.outputSize(1:2));T.warpDirection='forward';
 regList(k)=struct('sourceIdx',indices(k),'file',files{k},'T',T,'score',0); %#ok<AGROW>
end
shape=double(regList(1).T.outSize);
[entries,names,ctx]=fusiAtlasUnderlayLibrary2D(files,[shape numel(files)]);
assert(numel(entries)==4,'deConfUSIon:StepMotorUnderlays','This motor session does not contain all atlas underlay planes.');
for k=1:numel(entries),entries{k}.meta.registrationBundle2D=true;end
selected=find(strcmp(names,selectedName),1);if isempty(selected),selected=1;end
bundle=struct('folder',folder,'sessionFile',sessionFile,'sourceNSlices',session.sourceNSlices, ...
 'sourceSliceIndices',indices,'regList',regList,'entries',{entries},'names',{names}, ...
 'context',ctx,'selected',selected);
end
