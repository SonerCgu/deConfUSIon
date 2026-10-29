function files=gaPublicationExport(baseFile,renderer,options)
% Export the same physical-size figure and bracket positions as the preview.
if nargin<3,options=struct();end
presets=gaTitrationPublication('presets');index=field(options,'preset',1);p=presets(index);
if strcmpi(field(options,'theme','Light'),'Dark'),bg=[0 0 0];else,bg=[1 1 1];end
f=figure('Visible','off','Color',bg,'InvertHardcopy','off','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Units','centimeters', ...
    'Position',[2 2 p.widthMM/10 p.heightMM/10], ...
    'PaperUnits','centimeters','PaperSize',[p.widthMM p.heightMM]/10, ...
    'PaperPosition',[0 0 p.widthMM p.heightMM]/10,'PaperPositionMode','manual');
guard=onCleanup(@()delete(f)); %#ok<NASGU>
options.preview=false;renderer(f,options);drawnow nocallbacks;
[folder,name]=fileparts(baseFile);baseFile=fullfile(folder,name);files={};kind=field(options,'format','PNG');
if any(strcmpi(kind,{'PNG','Both'}))
    file=[baseFile '.png'];print(f,file,'-dpng','-r600');files{end+1}=file;
end
if any(strcmpi(kind,{'PDF','Both'}))
    file=[baseFile '.pdf'];print(f,file,'-dpdf','-painters');files{end+1}=file;
end
end

function out=field(S,name,fallback)
out=fallback;if isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end
