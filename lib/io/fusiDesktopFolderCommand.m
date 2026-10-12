function args=fusiDesktopFolderCommand(folder,platform)
% Argument lists for native folder opening; paths are never shell commands.
if nargin<2
    platform='unix';if ispc,platform='win';elseif ismac,platform='mac';end
end
switch lower(platform)
    case {'win','windows'},args={'explorer.exe',char(folder)};
    case {'mac','macos'},args={'/usr/bin/open',char(folder)};
    case {'unix','linux'},args={'xdg-open',char(folder)};
    otherwise,error('deConfUSIon:Platform','Unknown desktop platform: %s',platform);
end
end
