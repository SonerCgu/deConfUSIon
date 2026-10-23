function selection=fusiVolumeAtlasLink(action,par,selection)
% Remember a LightSuite project per scan and, where explicit, per animal.
if nargin<3,selection=[];end
root=fusiModelAnalysisFolder(par);scanFile=fullfile(root,'Registration','3DModel_Atlas.json');
files={scanFile};[parent,leaf]=fileparts(root);[~,animal]=fileparts(parent);
prefix=regexprep(leaf,'(?i)_scan[_-]?\d+.*$','');
if ~strcmp(prefix,leaf)&&strcmpi(prefix,animal)
    files{end+1}=fullfile(parent,'3DModel_LightSuiteAtlas.json');
end
switch action
    case 'get'
        for k=1:numel(files)
            if ~isfile(files{k}),continue;end
            try
                saved=jsondecode(fileread(files{k}));
                if isfield(saved,'disabled')&&saved.disabled,return;end
                if isfield(saved,'selection'),selection=saved.selection;end
                return;
            catch,continue;
            end
        end
    case {'set','clear'}
        saved=struct('version',1,'savedAt',datestr(now,30),'selection',selection,'disabled',strcmp(action,'clear'));
        if strcmp(action,'clear'),files=files(1);end
        for k=1:numel(files)
            folder=fileparts(files{k});if ~isfolder(folder),mkdir(folder);end
            fid=fopen(files{k},'w');assert(fid>=0,'Cannot save the 3D atlas selection: %s',files{k});
            cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(saved,'PrettyPrint',true));clear cleanup;
        end
    otherwise,error('Unknown 3D atlas link action: %s',action);
end
end
