function tests=testSCMImageGeometry
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testPickingIncludesEdgePixelsAndExcludesReferenceOnlyArea(testCase)
assumeTrue(testCase,usejava('awt'));
f=figure('Visible','off','Units','pixels');cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
ax=axes(f,'Units','pixels','Position',[40 40 360 240]);
image(ax,[-20 60],[-10 50],zeros(20,30,3));hold(ax,'on');
imagesc(ax,[1 28],[1 20],ones(20,28),'AlphaData',zeros(20,28));
text(ax,1,1,'A label can overlap an edge voxel');
ax.XLim=[-20 60];ax.YLim=[-10 50];ax.YDir='reverse';ax.DataAspectRatio=[1 1.5 1];
pos=getpixelposition(ax,true);point=pos(1:2)+pos(3:4)/2;
for xy=[.51 .51;28.49 .51;.51 20.49;28.49 20.49;14 10]'
    ray=[xy' 2;xy' -2];
    [picked,onImage,inside]=fusiImagePointer(ax,f,[20 28],point,ray);
    verifyTrue(testCase,onImage);verifyTrue(testCase,inside);verifyEqual(testCase,picked,xy');
end
[~,onImage,inside]=fusiImagePointer(ax,f,[20 28],point,[-5 10 2;-5 10 -2]);
verifyTrue(testCase,onImage);verifyFalse(testCase,inside);
[~,onImage]=fusiImagePointer(ax,f,[20 28],pos(1:2)-10,[14 10 2;14 10 -2]);
verifyFalse(testCase,onImage);
% The picker intersects the image plane, including an oblique ray.
[picked,~,inside]=fusiImagePointer(ax,f,[20 28],point,[12 8 2;16 12 -2]);
verifyTrue(testCase,inside);verifyEqual(testCase,picked,[14 10]);
end

function testHoverBoxCoversTheMeasuredPixelsExactly(testCase)
assumeTrue(testCase,usejava('awt'));
PSC=ones(20,28,4,31,'single');
baseline=struct('mode','sec','start',0,'end',20,'sigStart',60,'sigEnd',200);
f=SCM_gui(PSC,ones(20,28,4),10,struct(),baseline,31,'Voxel edge regression');
cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
queue=getappdata(f,'FUSIQueueHover');render=getappdata(f,'FUSIRenderHover');browse=getappdata(f,'FUSISetSlice');
box=findall(f,'Tag','SCM_LiveROIBox');
for xy=[1 1;28 1;1 20;28 20]'
    queue(xy(1),xy(2));render();position=box.Position;
    verifyGreaterThanOrEqual(testCase,position(1:2),[.5 .5]);
    verifyLessThanOrEqual(testCase,position(1:2)+position(3:4),[28.5 20.5]);
    verifyEqual(testCase,mod(position(1:2),1),[.5 .5]);
    verifyEqual(testCase,char(box.Visible),'on');
end
browse(1);verifyEqual(testCase,char(box.Visible),'off');
end

function testFittedBoundsKeepReferenceAndRecordingWithoutEmptyAtlasBox(testCase)
texture=zeros(61,101,4,'single');texture(21:41,26:66,:)=1;
geometry=struct('nativeSize',[20 28 4],'xData',[-50 50],'yData',[-30 30]);
bounds=fusiLightSuiteDisplayBounds(texture,geometry);
verifyLessThan(testCase,diff(bounds(1,:)),diff(geometry.xData));
verifyLessThan(testCase,diff(bounds(2,:)),diff(geometry.yData));
verifyLessThan(testCase,bounds(:,1),[-25;-10]);
verifyGreaterThan(testCase,bounds(:,2),[28.5;20.5]);
end
