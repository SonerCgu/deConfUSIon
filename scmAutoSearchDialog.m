function opt=scmAutoSearchDialog(ctx)
% Anatomy-only editor. Drawing never blocks callbacks or waits for extra clicks.
opt=[]; nz=ctx.sizeYXZ(3); ny=ctx.sizeYXZ(1); nx=ctx.sizeYXZ(2); z=ctx.slice;
accepted=false; armed=false; dragging=false; anchor=[]; rubber=[];
f=figure('Name','Automatic SCM | time and anatomical search regions','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Position',[100 100 1120 720],'Color','k','WindowStyle','modal');
setappdata(f,'deConfUSIonNoMaximize',true);
ax=axes('Parent',f,'Units','normalized','Position',[.47 .28 .50 .64]);
label(.94,sprintf('Baseline: %.3g-%.3g min | acquisition: %.3g min',ctx.baselineSec/60,(ctx.nT-1)*ctx.TR/60));
eSize=editrow(.86,'Square ROI side (pixels)',num2str(ctx.roiSize),'SearchROISize');
eTime=editrow(.79,'Search start/end (minutes)',sprintf('%.9g %.9g',ctx.signalSec/60),'SearchTime');
duration=0; if isfield(ctx,'plateauSec'), duration=ctx.plateauSec/60; end
eDuration=editrow(.72,'Plateau duration (minutes)', num2str(duration),'SearchPlateau');
label(.66,'0 = whole interval. E.g. 5 15 with duration 2 searches');
label(.63,'every 2-minute window between 5 and 15 minutes.');
eBounds=editrow(.56,'X start/end, Y start/end',sprintf('1 %d 1 %d',nx,ny),'SearchBounds');
set(eBounds,'Callback',@preview);
button(.49,'Draw rectangle: click and drag on image',@arm);
button(.43,'Reset search rectangle to full image',@reset);
cbBoth=control('checkbox',[.025 .36 .41 .04],'Separate left/right target and control',@preview);
set(cbBoth,'Value',1);
eSplit=editrow(.30,'Left/right boundary (X)',num2str(floor(nx/2)),'SearchSplit'); set(eSplit,'Callback',@preview);
label(.24,'Target side (as displayed in the image):');
pRole=control('popupmenu',[.025 .19 .405 .045],{'LEFT = Target / RIGHT = Control','RIGHT = Target / LEFT = Control'},@preview);
set(pRole,'Tag','SearchTargetSide');
cbAll=control('checkbox',[.025 .125 .41 .04],'Search all slices',[]); set(cbAll,'Value',double(nz>1));
if nz==1, set(cbAll,'Enable','off'); end
cbClean=control('checkbox',[.025 .075 .41 .04],'Positive display preset (0-30%, alpha 5-10%)',[]); set(cbClean,'Value',1);
pWindow=control('popupmenu',[.025 .015 .405 .045], ...
    {'Different best window per ROI / slice','Same best window across all slices'},[]);
set(pWindow,'Tag','SearchWindowMode','Value',2);
sliceText=control('text',[.48 .22 .48 .035],'',[]);
sl=control('slider',[.49 .18 .46 .025],'',@changeSlice);
set(sl,'Min',1,'Max',max(2,nz),'Value',z,'SliderStep',[1/max(1,nz-1) min(1,5/max(1,nz-1))],'Tag','SearchSlice');
if nz==1, set(sl,'Enable','off'); end
status=control('text',[.47 .075 .50 .09],'Choose settings, then click GO / Start analysis.',[]);
set(status,'HorizontalAlignment','left','Tag','SearchStatus');
go=control('pushbutton',[.47 .015 .31 .05],'GO / Start analysis',@accept);
set(go,'BackgroundColor',[.05 .4 .24],'FontWeight','bold','Tag','SearchGo');
control('pushbutton',[.80 .015 .17 .05],'Cancel',@(~,~)delete(f));
set(f,'WindowScrollWheelFcn',@scroll,'WindowButtonDownFcn',@mouseDown, ...
    'WindowButtonMotionFcn',@mouseMove,'WindowButtonUpFcn',@mouseUp,'WindowKeyPressFcn',@key);
preview(); setappdata(f,'SCMSearchDialogReady',true); uiwait(f);
if isgraphics(f), if accepted, opt=collect(); end; delete(f); end

    function h=control(style,pos,str,cb)
        bg=[.12 .12 .12]; if any(strcmp(style,{'text','checkbox'})), bg=[0 0 0]; end
        h=uicontrol(f,'Style',style,'Units','normalized','Position',pos,'String',str, ...
            'BackgroundColor',bg,'ForegroundColor','w','FontSize',10,'Callback',cb);
        setappdata(h,'PreserveColors',true);
    end
    function label(y,str)
        h=control('text',[.025 y .425 .035],str,[]); set(h,'HorizontalAlignment','left');
    end
    function h=editrow(y,str,value,tag)
        h=control('text',[.025 y .235 .04],str,[]); set(h,'HorizontalAlignment','left');
        h=control('edit',[.27 y .16 .045],value,[]); set(h,'Tag',tag);
    end
    function button(y,str,cb), control('pushbutton',[.025 y .405 .045],str,cb); end
    function o=collect()
        o=struct('size',str2double(get(eSize,'String')),'signalSec',60*sscanf(strrep(get(eTime,'String'),',',' '),'%f')', ...
            'plateauSec',60*str2double(get(eDuration,'String')),'sharedWindow',get(pWindow,'Value')==2, ...
            'boundsXY',sscanf(strrep(get(eBounds,'String'),',',' '),'%f')','bilateral',logical(get(cbBoth,'Value')), ...
            'splitX',str2double(get(eSplit,'String')),'leftIsTarget',get(pRole,'Value')==1, ...
            'allSlices',logical(get(cbAll,'Value')),'slice',z,'cleanDisplay',logical(get(cbClean,'Value')));
        o.polygons=cell(nz,2); % Keep the region helper/backward metadata contract.
    end
    function changeSlice(~,~), z=round(get(sl,'Value')); set(sl,'Value',z); preview(); end
    function scroll(~,event)
        if dragging, return; end
        z=max(1,min(nz,z+event.VerticalScrollCount)); set(sl,'Value',z); preview();
    end
    function preview(varargin)
        if dragging, return; end
        cla(ax); image(ax,ctx.underlay(z)); axis(ax,'image'); set(ax,'YDir','reverse','XColor','w','YColor','w','Color','k'); hold(ax,'on');
        title(ax,'Anatomy preview | X = columns, Y = rows','Color','w');
        set(sliceText,'String',sprintf('Slice %d / %d - scroll mouse wheel or move slider',z,nz));
        try
            o=collect(); r=scmSearchRegions(o,z,ctx.mask(z)); included=false(ny,nx);
            for k=1:numel(r)
                included=included|r(k).mask;
                c=[1 .55 .05]; if strcmp(r(k).role,'Control'), c=[.05 .65 1]; end
                padded=zeros(ny+2,nx+2); padded(2:end-1,2:end-1)=double(r(k).mask);
                if any(r(k).mask(:))
                    contour(ax,0:nx+1,0:ny+1,padded,[.5 .5],'Color',c,'LineWidth',2);
                    [yy,xx]=find(r(k).mask); text(ax,mean(xx),min(yy),r(k).role,'Color',c, ...
                        'FontWeight','bold','FontSize',12,'HorizontalAlignment','center','VerticalAlignment','top','BackgroundColor','k');
                end
            end
            h=image(ax,zeros(ny,nx,3)); set(h,'AlphaData',.55*double(~included));
            xlim(ax,[.5 nx+.5]); ylim(ax,[.5 ny+.5]);
        catch ME
            set(status,'String',ME.message,'ForegroundColor',[1 .45 .3]);
        end
        hold(ax,'off');
    end
    function arm(~,~)
        armed=true; set(f,'Pointer','crosshair');
        set(status,'String','Drag from one corner to the opposite corner. Release to apply; Esc cancels.','ForegroundColor','w');
    end
    function p=point(), q=get(ax,'CurrentPoint'); p=q(1,1:2); end
    function mouseDown(~,~)
        if ~armed||~strcmp(get(f,'SelectionType'),'normal'), return; end
        p=point(); if any(p<[.5 .5])||any(p>[nx+.5 ny+.5]), return; end
        anchor=p; dragging=true; set(go,'Enable','off');
        rubber=rectangle(ax,'Position',[p .01 .01],'EdgeColor','y','LineWidth',2,'LineStyle','--');
    end
    function mouseMove(~,~)
        if ~dragging, return; end
        p=max([.5 .5],min([nx+.5 ny+.5],point()));
        set(rubber,'Position',[min(anchor,p) max([.01 .01],abs(p-anchor))]); drawnow limitrate;
    end
    function mouseUp(~,~)
        if ~dragging, return; end
        p=max([.5 .5],min([nx+.5 ny+.5],point()));
        lo=max([1 1],ceil(min(anchor,p))); hi=min([nx ny],floor(max(anchor,p)));
        dragging=false; armed=false; set(go,'Enable','on'); set(f,'Pointer','arrow');
        if all(hi>=lo), set(eBounds,'String',sprintf('%d %d %d %d',lo(1),hi(1),lo(2),hi(2))); end
        set(status,'String','Rectangle applied to every searched slice. Ready to start.','ForegroundColor','w'); preview();
    end
    function key(~,event)
        if strcmp(event.Key,'escape'), dragging=false; armed=false; set(go,'Enable','on'); set(f,'Pointer','arrow'); preview(); end
    end
    function reset(~,~)
        dragging=false; armed=false; set(go,'Enable','on'); set(f,'Pointer','arrow');
        set(eBounds,'String',sprintf('1 %d 1 %d',nx,ny)); preview();
    end
    function accept(~,~)
        try
            o=collect(); w=o.signalSec;
            if numel(w)==2 && isfinite(w(2)) && w(2)>(ctx.nT-1)*ctx.TR
                w(2)=(ctx.nT-1)*ctx.TR; set(eTime,'String',sprintf('%.9g %.9g',w/60));
            end
            assert(isscalar(o.size)&&isfinite(o.size)&&o.size>=1&&o.size==round(o.size)&&o.size<=min(ny,nx), ...
                'ROI side must be a positive integer that fits the image.');
            assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>w(1)&&w(2)<=ctx.nT*ctx.TR, ...
                'Search start/end must be increasing and inside the acquisition (minutes).');
            scmSearchWindows(w,o.plateauSec,ctx.TR,ctx.nT);
            slices=z; if o.allSlices, slices=1:nz; end
            for zz=slices
                rr=scmSearchRegions(o,zz,ctx.mask(zz)); %#ok<NASGU>
            end
            b=o.boundsXY;
            assert(o.size<=min([b(2)-b(1)+1 b(4)-b(3)+1]),'ROI side is larger than the search rectangle. Reduce ROI size.');
            set(status,'String','Starting analysis...','ForegroundColor','w'); drawnow;
            accepted=true; uiresume(f);
        catch ME
            set(status,'String',['Cannot start: ' ME.message],'ForegroundColor',[1 .45 .3]); drawnow;
        end
    end
end
