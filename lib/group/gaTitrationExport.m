function files=gaTitrationExport(baseFile,R,S,options)
% Export the same physical-size renderer that is reviewed in the dialog.
if nargin<4,options=struct();end
renderer=@(parent,current)gaTitrationPublication('render',parent,R,S,current);
files=gaPublicationExport(baseFile,renderer,options);
end
