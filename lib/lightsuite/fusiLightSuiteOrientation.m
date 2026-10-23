function permutation=fusiLightSuiteOrientation(session)
% Explicit confirmation: closing the preview never accepts an orientation.
permutation=[];s=session;map=s.opts.permute_sample_to_atlas;
f=figure('Name','LightSuite - confirm physical orientation','NumberTitle','off', ...
    'Color',[.06 .08 .09],'MenuBar','none','ToolBar','none','Position',[140 100 1180 740], ...
    'CloseRequestFcn',@cancel);
uicontrol(f,'Style','text','Units','normalized','Position',[.03 .91 .94 .07], ...
    'String','Top: fixed vascular atlas. Bottom: your anatomy. Confirm AP / DV / ML and both hemispheres before continuing.', ...
    'ForegroundColor','w','BackgroundColor',f.Color,'FontSize',12,'HorizontalAlignment','left');
labels={'Input 1 (+)','Input 1 reversed (-)','Input 2 (+)','Input 2 reversed (-)','Input 3 (+)','Input 3 reversed (-)'};
values=[1 -1 2 -2 3 -3];axesNames={'AP','DV','ML'};dd=gobjects(1,3);ax=gobjects(2,3);
for k=1:3
    uicontrol(f,'Style','text','Units','normalized','Position',[.03+(k-1)*.3 .825 .1 .04], ...
        'String',['Atlas ' axesNames{k}],'BackgroundColor',f.Color,'ForegroundColor','w','FontSize',12);
    dd(k)=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.12+(k-1)*.3 .82 .19 .05], ...
        'String',labels,'Value',find(values==map(k),1),'FontSize',11,'Callback',@refresh);
    ax(1,k)=axes(f,'Units','normalized','Position',[.04+(k-1)*.32 .49 .29 .29]);
    ax(2,k)=axes(f,'Units','normalized','Position',[.04+(k-1)*.32 .15 .29 .29]);
end
status=uicontrol(f,'Style','text','Units','normalized','Position',[.03 .055 .66 .06], ...
    'String','','BackgroundColor',f.Color,'ForegroundColor',[1 .65 .3],'FontSize',11,'HorizontalAlignment','left');
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.73 .04 .24 .07], ...
    'String','Confirm geometry','FontSize',13,'FontWeight','bold','Callback',@accept);
fusiLightSuiteStyle(f);fusiLightSuiteLabelWindow(f,session);refresh();uiwait(f);if isgraphics(f),delete(f);end
    function refresh(~,~)
        for j=1:3,map(j)=values(dd(j).Value);end
        if ~isequal(sort(abs(map)),1:3),status.String='Choose each input dimension once.';return;end
        V=permute(s.opts.sample,abs(map));for j=1:3,if map(j)<0,V=flip(V,j);end,end
        for j=1:3
            drawView(ax(1,j),s.opts.atlas,j,s.opts.atlas_res,'Atlas');
            drawView(ax(2,j),V,j,s.opts.sample_res(abs(map)),'Sample');
        end
        status.String='Check anatomy and acquisition orientation. Origin in probe coordinates does not define Allen CCF placement.';
    end
    function drawView(a,V,d,res,caption)
        ix={':',':',':'};ix{d}=round(size(V,d)/2);plane=squeeze(V(ix{:}));
        q=double(plane(isfinite(plane)&plane>0));lim=[0 1];if ~isempty(q),lim=quantile(q,[.01 .99]);end
        if lim(2)<=lim(1),lim(2)=lim(1)+1;end
        imagesc(a,plane,lim);axis(a,'image');colormap(a,gray(256));a.XTick=[];a.YTick=[];
        remaining=setdiff(1:3,d,'stable');daspect(a,[1/res(remaining(2)) 1/res(remaining(1)) 1]);
        title(a,sprintf('%s: central %s plane',caption,axesNames{d}),'Color','w','FontSize',12);
    end
    function accept(~,~)
        if ~isequal(sort(abs(map)),1:3),return;end
        permutation=map;uiresume(f);
    end
    function cancel(~,~),permutation=[];uiresume(f);end
end
