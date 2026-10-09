function profile=scmSharedDisplay(action,profile)
% Explicitly remembered numerical limits; no per-animal rescaling.
if nargin<1, action='get'; end
if strcmp(action,'get')
    profile=struct('caxis',[0 30],'modMin',5,'modMax',10,'alphaPercent',100,'signMode',1);
    if ispref('deConfUSIon','SCMSharedDisplay'), profile=getpref('deConfUSIon','SCMSharedDisplay'); end
end
assert(isstruct(profile)&&all(isfield(profile,{'caxis','modMin','modMax','alphaPercent'})), ...
    'deConfUSIon:DisplayRange','Shared display settings are incomplete.');
v=[profile.caxis(:)' profile.modMin profile.modMax profile.alphaPercent];
assert(numel(v)==5&&all(isfinite(v))&&v(1)<v(2)&&v(3)>=0&&v(4)>v(3)&&v(5)>=0&&v(5)<=100, ...
    'deConfUSIon:DisplayRange','Use increasing color limits, an increasing nonnegative alpha ramp, and opacity from 0 to 100.');
profile.mode='shared';profile.rule='Fixed numerical limits, identical across animals';
if ~isfield(profile,'signMode'), profile.signMode=1; end
assert(isscalar(profile.signMode)&&ismember(profile.signMode,[1 2 3]),'deConfUSIon:DisplayRange','Invalid display polarity.');
profile.scope='all animals using shared display';
if strcmp(action,'set'), setpref('deConfUSIon','SCMSharedDisplay',profile);
elseif ~any(strcmp(action,{'get','validate'})), error('deConfUSIon:DisplayRange','Unknown display settings action.'); end
end
