function tests=testSCMSliceOrientation
tests=functiontests(localfunctions);
end

function testNormalUnderlayKeepsRenderedOrientationAcrossSlices(testCase)
assumeTrue(testCase,usejava('awt'));
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
shape=[20 28 4];PSC=zeros([shape 31],'single');
bg=repmat(single(reshape(1:prod(shape(1:2)),shape(1:2))),1,1,shape(3));
baseline=struct('mode','sec','start',0,'end',20,'sigStart',60,'sigEnd',200);
f=SCM_gui(PSC,bg,10,struct(),baseline,31,'Slice orientation regression');
cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
overlay=findall(f,'Tag','SCM_OverlayImage');ax=overlay.Parent;
reader=getappdata(f,'FUSIUnderlayData');initial=reader();browse=getappdata(f,'FUSISetSlice');
% These asymmetric corner markers test the rendered scene, not just axis
% property values. Positive camera-up with reversed image Y fails this test.
patch(ax,[2 7 7 2],[2 2 6 6],[1 0 0],'EdgeColor','none');
patch(ax,[22 27 27 22],[2 2 6 6],[0 1 0],'EdgeColor','none');
patch(ax,[2 7 7 2],[15 15 19 19],[0 0 1],'EdgeColor','none');
patch(ax,[22 27 27 22],[15 15 19 19],[1 1 0],'EdgeColor','none');
file=[tempname '.png'];imageCleanup=onCleanup(@()delete(file)); %#ok<NASGU>
verifyRenderedCorners(testCase,ax,file);
for z=[1 4 2 3 1]
    browse(z);drawnow;
    verifyRenderedCorners(testCase,ax,file);
    actual=reader();verifyEqual(testCase,actual.PSC,initial.PSC);
    verifyEqual(testCase,actual.underlay,initial.underlay);
    verifyEqual(testCase,overlay.XData,[1 shape(2)]);verifyEqual(testCase,overlay.YData,[1 shape(1)]);
end
sharp=findall(f,'Tag','SCM_SharpPixels');
for value=[0 1]
    sharp.Value=value;callback=sharp.Callback;callback(sharp,[]);
    verifyRenderedCorners(testCase,ax,file);
end
end

function verifyRenderedCorners(testCase,ax,file)
drawnow;exportgraphics(ax,file,'Resolution',72,'BackgroundColor','black');rgb=imread(file);
red=rgb(:,:,1)>180&rgb(:,:,2)<80&rgb(:,:,3)<80;
green=rgb(:,:,1)<80&rgb(:,:,2)>180&rgb(:,:,3)<80;
blue=rgb(:,:,1)<80&rgb(:,:,2)<80&rgb(:,:,3)>180;
yellow=rgb(:,:,1)>180&rgb(:,:,2)>180&rgb(:,:,3)<80;
centre=zeros(4,2);masks={red,green,blue,yellow};
for k=1:4
    [row,column]=find(masks{k});verifyGreaterThan(testCase,numel(row),10);
    centre(k,:)=[mean(row) mean(column)];
end
verifyLessThan(testCase,centre(1,1),centre(3,1)); % Red above blue.
verifyLessThan(testCase,centre(2,1),centre(4,1)); % Green above yellow.
verifyLessThan(testCase,centre(1,2),centre(2,2)); % Red left of green.
verifyLessThan(testCase,centre(3,2),centre(4,2)); % Blue left of yellow.
end
