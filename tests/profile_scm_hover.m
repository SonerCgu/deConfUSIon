function profile_scm_hover()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
work=tempname; mkdir(work); addpath(work);
source=fileread(fullfile(root,'SCM_gui.m'));
source=strrep(source,'function fig = SCM_gui(', 'function fig = SCM_profile_fixture(');
marker="set(fig,'DeleteFcn',@disposeHoverTimer);";
hooks="setappdata(fig,'ProfileHover',struct('queue',@queueHover,'render',@renderPendingHover,'compute',@computeRoiPSC_idx,'axes',@applyTimecourseAxisMode,'hit',@isPointerOverImageAxis,'rect',hLiveRect,'trace',hLivePSC,'timer',hoverTimer,'size',slROI,'resize',@setROIsize));";
source=strrep(source,marker,marker+newline+hooks);
fid=fopen(fullfile(work,'SCM_profile_fixture.m'),'w'); fwrite(fid,char(source)); fclose(fid);
cleanup=onCleanup(@()rmpath(work)); %#ok<NASGU>
P=single(10*randn(160,160,1500));
base=struct('start',0,'end',10,'sigStart',30,'sigEnd',50,'mode','sec');
f=SCM_profile_fixture(P,ones(160),.5,struct(),base,1500,'SCM performance measurement');
guard=onCleanup(@()delete(f)); %#ok<NASGU>
set(f,'WindowButtonMotionFcn',[]); h=getappdata(f,'ProfileHover'); drawnow;
info=rendererinfo(ancestor(h.trace,'axes')); disp(info);
profile clear; profile on;
for width=[5 25 101]
    set(h.size,'Value',width); h.resize();
    elapsed=zeros(1,15);
    for k=1:15
        t=tic; h.queue(72+k,80); h.render([],[]); elapsed(k)=toc(t);
        p=get(h.rect,'Position');
        expected=h.compute(1,p(1),p(1)+p(3)-1,p(2),p(2)+p(4)-1,1:2:1500);
        actual=get(h.trace,'YData');
        assert(isequal(isnan(actual),isnan(expected)));
        valid=isfinite(expected); assert(max(abs(actual(valid)-expected(valid)))<2e-5,'Incremental ROI differs from direct mean.');
    end
    stop(h.timer);
    fprintf('ROI %d: median %.4f s, max %.4f s\n',width,median(elapsed(3:end)),max(elapsed));
end
t=tic; for k=1:50, h.hit(); end; fprintf('Hit test %.4f s/call\n',toc(t)/50);
profile off; stats=profile('info'); save(fullfile(root,'validation','scm_hover_profile.mat'),'stats');
[~,order]=sort([stats.FunctionTable.TotalTime],'descend');
for k=order(1:min(22,numel(order)))
    row=stats.FunctionTable(k); fprintf('%.4f s | %d | %s\n',row.TotalTime,row.NumCalls,row.FunctionName);
end
end
