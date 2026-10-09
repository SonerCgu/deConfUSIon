function folder=fusiVolumeAtlasTransformFolder(par,transformFile)
% Start the 3D transform picker at the active scan's analysed registration.
if nargin<2,transformFile='';end
root=fusiModelAnalysisFolder(par);
if isfield(par,'scanSequence')&&isstruct(par.scanSequence)&&~isempty(par.scanSequence.scans)
    q=par.scanSequence;d=q.scans{q.active};
    if isfield(d,'rawFile')&&isfile(d.rawFile)
        paths=fusiResolveAnalysisFolder(d.rawFile);root=paths.datasetFolder;
    elseif isfield(d,'file')&&isfile(d.file)
        root=fusiModelAnalysisFolder(struct('exportPath',fileparts(d.file)));
    end
end
registrations={fullfile(root,'Registration'),fullfile(root,'Registration3D'), ...
    fullfile(root,'Visualization','Registration3D'),fullfile(root,'Visualization','Registration')};
% Respect a currently selected transform only if it belongs to this scan.
if isfile(transformFile)&&inside(fileparts(transformFile),root)
    folder=fileparts(transformFile);return;
end
files=[];
for k=1:numel(registrations)
    parent=registrations{k};if ~isfolder(parent),continue;end
    direct=dir(fullfile(parent,'Transformation.mat'));files=[files;direct(:)]; %#ok<AGROW>
    runs=dir(fullfile(parent,'AtlasRegistration_*'));runs=runs([runs.isdir]);
    for j=1:numel(runs)
        direct=dir(fullfile(runs(j).folder,runs(j).name,'Transformation.mat'));
        files=[files;direct(:)]; %#ok<AGROW>
    end
end
if ~isempty(files),[~,newest]=max([files.datenum]);folder=files(newest).folder;return;end
% A previously shared transform can be used across scans of this same animal.
if isfile(transformFile)&&~isRaw(transformFile)&&isfield(par,'scanSequence')&&fusiScanSequence('shareAtlas',par.scanSequence)
    parent=fileparts(root);
    if inside(fileparts(transformFile),parent),folder=fileparts(transformFile);return;end
end
for k=1:numel(registrations)
    if isfolder(registrations{k}),folder=registrations{k};return;end
end
% Empty/new registrations begin at the analysed scan, never RawData or pwd.
folder=root;
if ~isfolder(folder),[ok,message]=mkdir(folder);if ~ok,error('deConfUSIon:AtlasPickerFolder','Cannot open analysed folder %s: %s',folder,message);end,end
end
function yes=inside(folder,root)
folder=lower(strrep(folder,'\','/'));root=lower(regexprep(strrep(root,'\','/'),'/+$',''));
yes=strcmp(folder,root)||startsWith(folder,[root '/']);
end
function yes=isRaw(folder)
yes=~isempty(regexpi(strrep(folder,'\','/'),'(^|/)(RawData|Raw_Data_fUSI)(/|$)','once'));
end
