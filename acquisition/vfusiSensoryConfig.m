function c=vfusiSensoryConfig(c)
% Optional accessories. Missing settings leave the existing scanner untouched.
if nargin<1 || isempty(c),c=struct();end
d=struct('mode','disabled','protocol_file',fullfile(fileparts(mfilename('fullpath')),'sensory','defaults.json'), ...
    'python_exe','','output_dir',fullfile(pwd,'sensory_runs'),'udp_host','127.0.0.1','udp_port',45123);
names=fieldnames(d);for i=1:numel(names),if ~isfield(c,names{i}),c.(names{i})=d.(names{i});end,end
if ~any(strcmp(c.mode,{'disabled','mock','psychopy'})),error('vfUSI:SensoryConfig','Unknown sensory mode.');end
if strcmp(c.mode,'disabled'),return;end
if ~isfile(c.protocol_file),error('vfUSI:SensoryConfig','Choose an existing sensory JSON configuration.');end
if ~ischar(c.output_dir)||isempty(c.output_dir),error('vfUSI:SensoryConfig','Choose a sensory output folder.');end
if ~isscalar(c.udp_port)||~isfinite(c.udp_port)||c.udp_port~=round(c.udp_port)||c.udp_port<1024||c.udp_port>65535
    error('vfUSI:SensoryConfig','UDP port must be an integer from 1024 to 65535.');
end
if ~strcmp(c.udp_host,'127.0.0.1'),error('vfUSI:SensoryConfig','Use localhost (127.0.0.1) for the stimulus worker.');end
end
