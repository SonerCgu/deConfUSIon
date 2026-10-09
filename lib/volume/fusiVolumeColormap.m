function cm=fusiVolumeColormap(name,n)
% Match Video's named palettes. Inherited custom maps are passed directly.
if nargin<2,n=256;end
switch lower(name)
    case 'blackbdy_iso'
        if exist('blackbdy_iso','file'),cm=blackbdy_iso(n);else,cm=hot(n);end
        cm(1,:)=0;
    case 'winter_brain_fsl'
        if exist('winter_brain_fsl','file'),cm=winter_brain_fsl(n);else,cm=winter(n);end
    case 'signed_blackbdy_winter'
        nn=floor(n/2);np=n-nn;
        neg=fusiVolumeColormap('winter_brain_fsl',nn).*linspace(1,0,nn)';
        neg(end,:)=0;pos=fusiVolumeColormap('blackbdy_iso',np);pos(1,:)=0;cm=[neg;pos];
    otherwise
        if exist(name,'file') || any(strcmp(name,{'hot','jet','gray','bone','copper','pink','parula','turbo'})),cm=feval(name,n);
        else,cm=jet(n);end
end
cm=min(1,max(0,cm));
end
