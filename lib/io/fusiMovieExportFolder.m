function [folder,identity]=fusiMovieExportFolder(par,label,category,maxLeafLength,includeSequence)
% Reserve one readable, unique folder per export; keep full source identity.
if nargin<3,category='Videos';end
if nargin<4,maxLeafLength=48;end
if nargin<5,includeSequence=false;end
identity=fusiMovieExportIdentity(par,label,includeSequence);
root=fusiModelAnalysisFolder(par);
if includeSequence&&numel(identity.scans)>1
    [animalRoot,dataset]=fileparts(root);animal=regexprep(dataset,'_scan\d+(?:_ES)?$','','ignorecase');
    sameAnimal=~strcmp(animal,dataset);
    for k=1:numel(identity.scans)
        [~,rawName]=fileparts(identity.scans(k).rawFile);
        sameAnimal=sameAnimal&&strcmpi(regexprep(rawName,'_scan\d+(?:_ES)?$','','ignorecase'),animal);
    end
    if sameAnimal,root=animalRoot;end
end
parent=fullfile(root,category);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
% Keep room for the movie, paper companion, sidecar and collision suffix.
budget=max(0,min(80,240-numel(parent)-numel(stamp)-maxLeafLength-7));
short=identity.nameLabel;
if numel(short)>budget
    if budget>=16
        % Preserve scan identity at the start and the final processing step.
        tail=min(20,floor(budget/3));short=[short(1:budget-tail-1) '_' short(end-tail+1:end)];
    else,short=short(1:budget);end
end
short=regexprep(short,'_+$','');name=stamp;if ~isempty(short),name=[name '_' short];end
folder=fusiUniqueOutputFolder(parent,name);
identity.exportedAt=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
identity.folder=folder;identity.folderLabel=short;
end
