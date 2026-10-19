function [file,profile]=fusiMovieOutput(file,platform)
% MATLAB's native H.264 writer is available on Windows/macOS, not Linux.
% Linux uses Motion JPEG AVI, keeping the acquired frames and export FPS.
% An explicit platform supports checking format selection on another host.
if nargin<2
    platform='linux';if ispc,platform='win';elseif ismac,platform='mac';end
end
file=char(file);profile='MPEG-4';
switch lower(char(platform))
    case {'win','windows','mac','macos'}
        return; % Preserve existing Windows/macOS filenames and encoder.
    case {'linux','unix'}
        [folder,name,extension]=fileparts(file);
        assert(any(strcmpi(extension,{'.mp4','.avi'})), ...
            'deConfUSIon:MovieFormat','Choose an MP4 or AVI movie filename.');
        file=fullfile(folder,[name '.avi']);profile='Motion JPEG AVI';
    otherwise
        error('deConfUSIon:Platform','Unknown movie platform: %s',char(platform));
end
end
