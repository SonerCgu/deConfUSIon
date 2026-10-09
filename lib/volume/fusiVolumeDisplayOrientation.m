function orientation=fusiVolumeDisplayOrientation(S,nativeSide,confirmed,choice)
% Presentation only. Never change native samples or the saved atlas affine.
if nargin<4,choice='As acquired';end
nativeSide=lower(char(nativeSide));
assert(any(strcmp(nativeSide,{'left','right'})),'Invalid acquisition column-one side.');
sourceSide=nativeSide;
if isfield(S,'atlasAxisOrder'),sourceSide='left';end
shownSide=nativeSide;
switch choice
    case 'Left on image left',shownSide='left';
    case 'Right on image left',shownSide='right';
    case 'As acquired'
    otherwise,error('deConfUSIon:DisplayOrientation','Unknown display convention.');
end
orientation=struct('acquiredColumnOneSide',nativeSide,'sourceColumnOneSide',sourceSide, ...
    'columnOneSide',shownSide,'confirmed',logical(confirmed),'convention',choice, ...
    'flipColumns',~strcmp(sourceSide,shownSide), ...
    'rule','Display columns only; native samples and the saved registration matrix are unchanged.');
end
