function tests=testGeometricAutoMask
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testWeakAreasAndInteriorHolesStayInsideStraightEdges(testCase)
seed=false(80,100,6);seed(10:70,15:90,2:5)=true;
seed(10:35,30:50,:)=false;seed(40:50,60:80,:)=false;
seed(1,1,3)=true; % Isolated bright outlier must not set the outer bounds.
[mask,report]=fusiGeometricMaskVolume(seed);
verifyEqual(testCase,report.bounds,[15 90 10 70]);
expected=false(size(seed));expected(10:70,15:90,2:5)=true;
verifyEqual(testCase,mask,expected);
verifyEqual(testCase,report.voxelCount,nnz(expected));
end

function testSharedBoxDoesNotFollowSliceIntensityChanges(testCase)
seed=false(60,80,5);
seed(10:50,15:65,1:2)=true;seed(15:45,20:60,3:5)=true;
[mask,report]=fusiGeometricMaskVolume(seed);
for z=2:5,verifyEqual(testCase,mask(:,:,z),mask(:,:,1));end
verifyTrue(testCase,mask(12,17,5));
verifyEqual(testCase,report.bounds,[15 65 10 50]);
end

function testBrainRestrictionIncludesHolesAndEmptyPlanes(testCase)
seed=true(30,40,4);brain=true(size(seed));
brain(1:3,:,:)=false;brain(10:12,15:17,:)=false;brain(:,:,3)=false;
[mask,report]=fusiGeometricMaskVolume(seed,[5 35 2 28],brain);
expected=false(size(seed));expected(2:28,5:35,:)=true;expected=expected & brain;
verifyEqual(testCase,mask,expected);verifyTrue(testCase,report.restrictionApplied);
verifyFalse(testCase,any(mask(:,:,3),'all'));
end

function testNativeBoundsClipWithoutFlippingOrResampling(testCase)
seed=true(12,18,3);valid=[true false true];
[mask,report]=fusiGeometricMaskVolume(seed,[-5 50 2.2 4.1],[],valid);
expected=false(size(seed));expected(2:4,1:18,[1 3])=true;
verifyEqual(testCase,mask,expected);verifyEqual(testCase,report.bounds,[1 18 2 4]);
end

function testBlankAndNonfiniteProposalsRemainEmpty(testCase)
[mask,report]=fusiGeometricMaskVolume(nan(10,20,3));
verifyFalse(testCase,any(mask(:)));verifyEmpty(testCase,report.bounds);
verifyFalse(testCase,any(report.validSlices));
[mask,~]=fusiGeometricMaskVolume(zeros(10,20),[2 18 3 8]);
verifyFalse(testCase,any(mask(:)));
end

function testEllipseHasRoundedCornersAndRetainsWeakCenter(testCase)
seed=true(41,61,4);seed(16:26,20:40,:)=false;
[mask,report]=fusiGeometricMaskVolume(seed,[5 57 3 39],[],[true true true false],'ellipse');
verifyTrue(testCase,mask(21,31,1));verifyFalse(testCase,mask(3,5,1));
verifyEqual(testCase,mask(:,:,1),flipud(mask(:,:,1)));
verifyEqual(testCase,mask(:,:,1),fliplr(mask(:,:,1)));
verifyEqual(testCase,mask(:,:,1),mask(:,:,3));
verifyFalse(testCase,any(mask(:,:,4),'all'));verifyEqual(testCase,report.shape,'ellipse');
end

function testSmoothingAllSlicesPreservesEmptyPlanesAndRestrictions(testCase)
seed=false(60,80,4);seed(10:50,15:65,1:3)=true;
seed(1,1,1:3)=true;seed(25,30,1:3)=false;
brain=true(size(seed));brain(30:32,40:42,:)=false;brain(:,:,3)=false;
mask=fusiSmoothMaskVolume(seed,2,1:4,brain);
verifyFalse(testCase,any(mask(1,1,:),'all'));verifyTrue(testCase,mask(25,30,1));
verifyFalse(testCase,any(mask(30:32,40:42,:),'all'));
verifyFalse(testCase,any(mask(:,:,3:4),'all'));verifyEqual(testCase,mask(:,:,1),mask(:,:,2));
end

function testPerSliceEllipsesGrowAndShrinkWithoutResampling(testCase)
seed=true(60,80,4);boxes=[26 50 21 39;11 65 8 52;22 55 16 44;1 80 1 60];
[mask,report]=fusiGeometricMaskVolume(seed,boxes,[],[true true true false],'ellipse');
areas=reshape(sum(sum(mask,1),2),1,[]);
verifyGreaterThan(testCase,areas(2),2*areas(1));verifyGreaterThan(testCase,areas(2),areas(3));
verifyTrue(testCase,mask(30,38,1));verifyFalse(testCase,mask(8,11,2));
verifyFalse(testCase,any(mask(:,:,4),'all'));verifyEqual(testCase,report.boundsBySlice,boxes);
verifyEqual(testCase,size(mask),size(seed));
end

function testMissingOutlinesInterpolateWithoutCrossingBlankSlices(testCase)
seed=false(60,80,5);seed(20:40,25:45,1)=true;seed(6:55,10:65,3)=true;
[boxes,report]=fusiSliceMaskBounds(seed,[true true true false true]);
verifyEqual(testCase,boxes(1,:),[25 45 20 40]);verifyEqual(testCase,boxes(3,:),[10 65 6 55]);
verifyEqual(testCase,boxes(2,:),mean(boxes([1 3],:),1));
verifyTrue(testCase,all(isnan(boxes(4:5,:)),'all'));
verifyEqual(testCase,report.interpolatedSlices,[false true false false false]);
verifyEqual(testCase,report.unresolvedSlices,[false false false false true]);
end

function testSmoothingCurrentSliceLeavesOtherSlicesUnchanged(testCase)
seed=false(50,70,3);seed(8:42,10:60,:)=true;seed(1,1,:)=true;
mask=fusiSmoothMaskVolume(seed,2,2);
verifyEqual(testCase,mask(:,:,[1 3]),seed(:,:,[1 3]));
verifyFalse(testCase,mask(1,1,2));verifyTrue(testCase,mask(25,35,2));
end

function testPreviewApplyKeepsNativeOrientationAndWholeStackScope(testCase)
assumeTrue(testCase,usejava('awt'));
seed=false(30,40,4);seed(4:26,5:35,1:3)=true;
U=single(seed);U(4,5,1)=10;options=struct('flipUD',true,'slice',1);
timerObj=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@applyPreview);
guard=onCleanup(@()stopAndDelete(timerObj)); %#ok<NASGU>
start(timerObj);selection=fusiGeometricMaskDialog(U,seed,options);
verifyEqual(testCase,selection.bounds,[7 32 6 24]);
verifyEqual(testCase,selection.slices,1:4); % Blank planes are cleared on apply.
verifyEqual(testCase,selection.inset,0);

    function applyPreview(t,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');
        if ~previewReady(f),return;end
        stop(t);
        cleanup=onCleanup(@()cancelIfWaiting(f)); %#ok<NASGU>
        ax=ancestor(findobj(f,'Tag','RectanglePreviewImage'),'axes');
        verifyEqual(testCase,ax.YDir,'reverse');
        roi=findobj(f,'Tag','RectangleROI');
        verifyNotEmpty(testCase,roi);
        verifyEqual(testCase,roi.Position,[4.5 3.5 31 23]);
        for k=1:4
            e=findobj(f,'Tag',['RectangleBound' num2str(k)]);
            vals=[7 32 6 24];e.String=num2str(vals(k));e.Callback(e,[]);
        end
        apply=findobj(f,'Tag','RectangleApply');apply.Callback(apply,[]);
    end
end

function testPreviewCurrentSliceInsetAndCancel(testCase)
assumeTrue(testCase,usejava('awt'));
seed=true(30,40,4);options=struct('flipUD',false,'slice',2,'inset',2);
timerObj=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@applyCurrent);
guard=onCleanup(@()stopAndDelete(timerObj)); %#ok<NASGU>
start(timerObj);selection=fusiGeometricMaskDialog(single(seed),seed,options);
verifyEqual(testCase,selection.bounds,[3 38 3 28]);verifyEqual(testCase,selection.slices,3);
timerObj2=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@cancelPreview);
guard2=onCleanup(@()stopAndDelete(timerObj2)); %#ok<NASGU>
start(timerObj2);
selection=fusiGeometricMaskDialog(single(seed),seed,options);verifyEmpty(testCase,selection);

    function applyCurrent(t,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');
        if ~previewReady(f),return;end
        stop(t);
        cleanup=onCleanup(@()cancelIfWaiting(f)); %#ok<NASGU>
        ax=ancestor(findobj(f,'Tag','RectanglePreviewImage'),'axes');
        verifyEqual(testCase,ax.YDir,'normal');
        scope=findobj(f,'Tag','RectangleScope');scope.Value=2;scope.Callback(scope,[]);
        slider=findobj(f,'Tag','RectangleSlice');slider.Value=3;slider.Callback(slider,[]);
        apply=findobj(f,'Tag','RectangleApply');apply.Callback(apply,[]);
    end
    function cancelPreview(t,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');
        if ~previewReady(f),return;end
        stop(t);
        cancel=findobj(f,'Tag','RectangleCancel');cancel.Callback(cancel,[]);
    end
end

function testPreviewCanChangeRectangleToEllipse(testCase)
assumeTrue(testCase,usejava('awt'));
seed=true(30,40,3);
timerObj=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@applyEllipse);
guard=onCleanup(@()stopAndDelete(timerObj)); %#ok<NASGU>
start(timerObj);selection=fusiGeometricMaskDialog(single(seed),seed,struct());
verifyEqual(testCase,selection.shape,'ellipse');

    function applyEllipse(t,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');
        if ~previewReady(f),return;end
        stop(t);cleanup=onCleanup(@()cancelIfWaiting(f)); %#ok<NASGU>
        shape=findobj(f,'Tag','GeometricShape');shape.Value=2;shape.Callback(shape,[]);
        apply=findobj(f,'Tag','RectangleApply');apply.Callback(apply,[]);
    end
end

function testOverlayPreviewFollowsSlicesAndPropagatesEdits(testCase)
assumeTrue(testCase,usejava('awt'));seed=taperedSeed();
options=struct('target','overlay / signal','shape','ellipse','slice',2,'inset',1);
t=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@editPreview);
guard=onCleanup(@()stopAndDelete(t)); %#ok<NASGU>
start(t);selection=fusiGeometricMaskDialog(single(seed),seed,options);
verifyTrue(testCase,selection.followSlices);verifyEqual(testCase,selection.bounds,[9 33 8 24]);
verifyLessThan(testCase,diff(selection.boundsBySlice(1,1:2)),diff(selection.boundsBySlice(2,1:2)));
mask=fusiGeometricMaskVolume(seed,selection.boundsBySlice,[],[true true true false],selection.shape);
verifyGreaterThan(testCase,nnz(mask(:,:,2)),nnz(mask(:,:,1)));verifyFalse(testCase,any(mask(:,:,4),'all'));

    function editPreview(timerObj,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');if ~previewReady(f),return;end
        stop(timerObj);cleanup=onCleanup(@()cancelIfWaiting(f)); %#ok<NASGU>
        follow=findobj(f,'Tag','GeometricFollowSlices');verifyEqual(testCase,follow.Value,1);
        values=[8 34 7 25];
        for k=1:4
            edit=findobj(f,'Tag',['RectangleBound' num2str(k)]);edit.String=num2str(values(k));edit.Callback(edit,[]);
        end
        roi=findobj(f,'Tag','RectangleROI');wide=roi.Position(3);
        slider=findobj(f,'Tag','RectangleSlice');slider.Value=1;slider.Callback(slider,[]);
        verifyLessThan(testCase,roi.Position(3),wide);
        slider.Value=2;slider.Callback(slider,[]);verifyEqual(testCase,roi.Position(3),wide);
        apply=findobj(f,'Tag','RectangleApply');apply.Callback(apply,[]);
    end
end

function testOverlayCanKeepOneFixedSizeWhenFollowIsDisabled(testCase)
assumeTrue(testCase,usejava('awt'));seed=taperedSeed();
t=timer('StartDelay',1,'Period',.25,'ExecutionMode','fixedSpacing','TimerFcn',@keepFixed);
guard=onCleanup(@()stopAndDelete(t)); %#ok<NASGU>
start(t);selection=fusiGeometricMaskDialog(single(seed),seed,struct('target','overlay / signal','slice',2));
verifyFalse(testCase,selection.followSlices);
verifyEqual(testCase,selection.boundsBySlice,repmat(selection.bounds,4,1));

    function keepFixed(timerObj,~)
        f=findall(groot,'Tag','FUSIGeometricMaskDialog');if ~previewReady(f),return;end
        stop(timerObj);cleanup=onCleanup(@()cancelIfWaiting(f)); %#ok<NASGU>
        roi=findobj(f,'Tag','RectangleROI');position=roi.Position;
        follow=findobj(f,'Tag','GeometricFollowSlices');follow.Value=0;follow.Callback(follow,[]);
        slider=findobj(f,'Tag','RectangleSlice');slider.Value=1;slider.Callback(slider,[]);
        verifyEqual(testCase,roi.Position,position);
        apply=findobj(f,'Tag','RectangleApply');apply.Callback(apply,[]);
    end
end

function seed=taperedSeed()
seed=false(32,42,4);seed(10:20,12:30,1)=true;seed(5:27,6:36,2)=true;seed(12:23,15:28,3)=true;
end

function ready=previewReady(f)
ready=isscalar(f) && isequal(getappdata(f,'FUSIGeometricMaskReady'),true) ...
    && strcmp(get(f,'WaitStatus'),'waiting');
end

function cancelIfWaiting(f)
if isgraphics(f) && strcmp(get(f,'WaitStatus'),'waiting')
    cancel=findobj(f,'Tag','RectangleCancel');cancel.Callback(cancel,[]);
end
end

function stopAndDelete(t)
if isvalid(t),stop(t);delete(t);end
f=findall(groot,'Tag','FUSIGeometricMaskDialog');if ~isempty(f),delete(f);end
end
