function lut=fusiRegionColorLUT(info,n,scheme)
% Region 0 and named atlas background are black, independently of PSC colors.
if nargin<2,n=numel(info.name);end
if nargin<3,scheme='Atlas';end
if strcmpi(scheme,'Atlas')&&isstruct(info)&&isfield(info,'acr')
 corrected=deConfUSIon_apply_rgb2acr(struct('infoRegions',info));info=corrected.infoRegions;
end
lut=lines(max(1,n));
if isstruct(info)&&isfield(info,'rgb')&&~isempty(info.rgb)
 c=double(info.rgb);if max(c(:))>1,c=c/255;end
 lut(1:min(n,size(c,1)),:)=c(1:min(n,size(c,1)),:);
end
switch lower(char(scheme))
 case 'distinct',lut=hsv2rgb([mod((0:max(1,n)-1)'*.61803398875,1) .70*ones(max(1,n),1) .95*ones(max(1,n),1)]);
 case 'pastel',lut=hsv2rgb([mod((0:max(1,n)-1)'*.61803398875,1) .35*ones(max(1,n),1) .95*ones(max(1,n),1)]);
 case 'grayscale',lut=repmat(linspace(.25,.95,max(1,n))',1,3);
end
if isstruct(info)&&isfield(info,'name')
 names=cellstr(string(info.name));
 for k=1:min(n,numel(names))
  if any(strcmpi(strtrim(names{k}),{'background','outside','root','unlabeled','unlabelled'})),lut(k,:)=0;end
 end
end
lut=min(max(lut,0),1);
end
