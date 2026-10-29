function [lg,box,reserve]=gaPublicationLegend(action,ax,options,style,box)
% Shared export-only legend visibility and measured corner placement.
lg=[];try,lg=get(ax,'Legend');catch,end
reserve=0;if nargin<5,box=[];end
if isempty(lg)||~isgraphics(lg),lg=[];box=[];return;end
if ~setting(options,'showLegend',true),set(lg,'Visible','off');lg=[];box=[];return;end
location=setting(options,'legendPosition','above-right');
if ~any(strcmp(location,{'above-right','above-left','inside-northeast','inside-northwest','inside-southeast','inside-southwest'}))
    location='above-right';
end
outside=startsWith(location,'above-');
switch lower(action)
    case 'measure'
        names=get(lg,'String');columns=1;
        if outside,columns=min(2,numel(names));end
        set(lg,'Visible','on','FontUnits','points','FontName','Arial','FontSize',style.font*style.scale, ...
            'FontWeight','normal','Orientation','horizontal','NumColumns',columns,'Units','pixels', ...
            'TextColor',style.fg,'Color','none','EdgeColor','none','Box','off','AutoUpdate','off');
        drawnow nocallbacks;box=get(lg,'Position');
        if box(3)>style.dataWidth&&columns>1
            set(lg,'NumColumns',1);drawnow nocallbacks;box=get(lg,'Position');
        end
        if box(3)>style.width-2*style.mm
            error('GroupAnalysis:PublicationLegendSize','The legend needs more space. Choose Square or Wide.');
        end
        if outside,reserve=box(4)+style.gap;end
    case 'place'
        if isempty(box),return;end
        data=getpixelposition(ax);inset=2*style.mm;
        switch location
            case 'above-right',box(1)=style.width-style.right-box(3);box(2)=style.height-style.top-box(4);
            case 'above-left',box(1)=style.left;box(2)=style.height-style.top-box(4);
            case 'inside-northeast',box(1)=sum(data([1 3]))-inset-box(3);box(2)=sum(data([2 4]))-inset-box(4);
            case 'inside-northwest',box(1)=data(1)+inset;box(2)=sum(data([2 4]))-inset-box(4);
            case 'inside-southeast',box(1)=sum(data([1 3]))-inset-box(3);box(2)=data(2)+inset;
            case 'inside-southwest',box(1)=data(1)+inset;box(2)=data(2)+inset;
        end
        box(1)=max(style.mm,min(style.width-style.mm-box(3),box(1)));
        box(2)=max(style.mm,min(style.height-style.mm-box(4),box(2)));
        set(lg,'Position',box);
    otherwise
        error('GroupAnalysis:PublicationLegendAction','Unknown legend action: %s',action);
end
end

function value=setting(S,name,fallback)
value=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),value=S.(name);end
end
