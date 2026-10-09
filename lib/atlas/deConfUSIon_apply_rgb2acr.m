function atlas=deConfUSIon_apply_rgb2acr(atlas,rgbFile)
% Apply the supplied ABA ontology HEX/acronym table without changing labels.
if nargin<2||isempty(rgbFile)
 rgbFile=fullfile(deConfUSIon_root(),'atlas_tools','rgb2acr.xlsx');
end
if ~isstruct(atlas)||~isfield(atlas,'infoRegions')||~isfield(atlas.infoRegions,'acr')||~isfile(rgbFile),return;end
info=atlas.infoRegions;acr=cellstr(string(info.acr(:)));[names,colors,revision]=readColors(rgbFile);
if isempty(names),return;end
persistent entries
if isempty(entries),entries={};end
mapped=[];
for k=1:numel(entries)
 if isequal(entries{k}.revision,revision)&&isequal(entries{k}.acr,acr),mapped=entries{k}.rgb;break;end
end
if isempty(mapped)
 mapped=nan(numel(acr),3);
 for k=1:numel(acr)
  name=strtrim(acr{k});hit=find(strcmpi(names,name),1);
  if ~isempty(hit),mapped(k,:)=colors(hit,:);continue;end
  % Same fallback as the colleague's save_correct_colors: mean colours
  % containing the first three letters, then the first two letters.
  if isempty(name),continue;end
  hit=find(contains(names,name(1:min(3,end))));
  if isempty(hit),hit=find(contains(names,name(1:min(2,end))));end
  if ~isempty(hit),mapped(k,:)=mean(colors(hit,:),1);end
 end
 if numel(entries)>=8,entries(1)=[];end
 entries{end+1}=struct('revision',revision,'acr',{acr},'rgb',mapped);
end
old=.5*ones(numel(acr),3);
if isfield(info,'rgb')&&isnumeric(info.rgb)&&size(info.rgb,2)==3
 previous=double(info.rgb);if max(previous(:))>1,previous=previous/255;end
 n=min(size(previous,1),size(old,1));old(1:n,:)=previous(1:n,:);
end
missing=any(~isfinite(mapped),2);mapped(missing,:)=old(missing,:);
info.rgb=min(max(mapped,0),1);info.rgb2=info.rgb;
info.colorSource='ABA ontology: rgb2acr.xlsx (JM exact and substring-mean mapping)';
atlas.infoRegions=info;
end

function [names,colors,revision]=readColors(file)
persistent savedRevision savedNames savedColors
d=dir(file);revision=struct('file',char(file),'bytes',d.bytes,'datenum',d.datenum);
if isequal(savedRevision,revision),names=savedNames;colors=savedColors;return;end
raw=readcell(file);names={};colors=zeros(0,3);
if isempty(raw),return;end
% The supplied workbook has no header: column A is HEX, column B acronym.
first=hexRGB(raw{1,1});
if size(raw,2)==2&&~isempty(first)
 start=1;ac=2;hc=1;rgb=[];
else
 keys=lower(regexprep(string(raw(1,:)),'[^a-zA-Z0-9]',''));
 ac=find(ismember(keys,["acr","acronym","acronyms"]),1);
 hc=find(ismember(keys,["hex","color","colour","hexcolor"]),1);
 rgb=[find(ismember(keys,["r","red"]),1) find(ismember(keys,["g","green"]),1) find(ismember(keys,["b","blue"]),1)];
 start=2;if isempty(ac),return;end
end
for row=start:size(raw,1)
 name=char(strtrim(erase(string(raw{row,ac}),'"')));if isempty(name)||strcmp(name,'<missing>'),continue;end
 color=[];
 if ~isempty(hc),color=hexRGB(raw{row,hc});
 elseif numel(rgb)==3
  color=zeros(1,3);
  for j=1:3,color(j)=str2double(string(raw{row,rgb(j)}));end
  if max(color)>1,color=color/255;end
 end
 if numel(color)==3&&all(isfinite(color))&&all(color>=0&color<=1)
  names{end+1,1}=name;colors(end+1,:)=color; %#ok<AGROW>
 end
end
savedRevision=revision;savedNames=names;savedColors=colors;
end
function rgb=hexRGB(value)
rgb=[];
if isnumeric(value)&&isscalar(value)&&isfinite(value),value=sprintf('%06.0f',value);end
s=char(erase(strtrim(string(value)),["#",'"']));
if isempty(regexp(s,'^[0-9A-Fa-f]{6}$','once')),return;end
rgb=[hex2dec(s(1:2)) hex2dec(s(3:4)) hex2dec(s(5:6))]/255;
end
