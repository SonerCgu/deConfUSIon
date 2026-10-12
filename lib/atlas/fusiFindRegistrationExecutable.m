function exe=fusiFindRegistrationExecutable(kind,platform,extra)
% Discover native ITK-SNAP/Greedy, including macOS app bundles and Homebrew.
if nargin<2,platform='unix';if ispc,platform='win';elseif ismac,platform='mac';end,end
if nargin<3,extra={};end
if ischar(extra),extra={extra};end
windows=strcmp(platform,'win');mac=strcmp(platform,'mac');
switch lower(kind)
    case 'greedy',pref='greedyExecutable';names={'greedy'};bundleNames={'bin/greedy','MacOS/greedy'};
    case 'snap',pref='itksnapExecutable';names={'itksnap','ITK-SNAP'};bundleNames={'MacOS/ITK-SNAP','MacOS/itksnap','bin/itksnap'};
    otherwise,error('deConfUSIon:RegistrationExecutable','Unknown registration tool: %s',kind);
end
if windows,names=cellfun(@(n)[n '.exe'],names,'UniformOutput',false);end
preferred=getpref('deConfUSIon',pref,'');candidates=[{preferred} extra];
dirs=strsplit(getenv('PATH'),pathsep);
if windows
    installs=dir(fullfile(getenv('ProgramFiles'),'ITK-SNAP*'));
    for k=numel(installs):-1:1,dirs{end+1}=fullfile(installs(k).folder,installs(k).name,'bin');end %#ok<AGROW>
elseif mac
    dirs=[dirs {'/opt/homebrew/bin','/usr/local/bin'}];
    for parent={'/Applications',fullfile(getenv('HOME'),'Applications')}
        bundles=dir(fullfile(parent{1},'*SNAP*.app'));
        for k=1:numel(bundles),candidates{end+1}=fullfile(bundles(k).folder,bundles(k).name);end %#ok<AGROW>
    end
end
for k=1:numel(dirs)
    for j=1:numel(names),candidates{end+1}=fullfile(dirs{k},names{j});end %#ok<AGROW>
end
exe='';
for k=1:numel(candidates)
    candidate=char(candidates{k});if isempty(candidate),continue;end
    if mac&&isfolder(candidate)&&endsWith(candidate,'.app','IgnoreCase',true)
        for j=1:numel(bundleNames)
            child=fullfile(candidate,'Contents',strrep(bundleNames{j},'/',filesep));
            if isfile(child),exe=child;return;end
        end
    elseif isfile(candidate),exe=candidate;return;end
end
end
