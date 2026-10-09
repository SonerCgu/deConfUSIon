function camera=fusiVolumeRefitStackCamera(camera,oldPoints,newPoints,viewport)
% Fit a changed layout while retaining rotation and relative user zoom.
if isempty(oldPoints)||isempty(newPoints),return;end
direction=camera.position-camera.target;distance=norm(direction);direction=direction/distance;
forward=-direction;right=cross(forward,camera.up);right=right/norm(right);up=cross(right,forward);
aspect=max(.1,viewport(1)/max(1,viewport(2)));
oldSpan=span(oldPoints);newSpan=span(newPoints);
center=(min(newPoints,[],1)+max(newPoints,[],1))/2;
camera.target=center;camera.position=center+direction*distance*newSpan/max(eps,oldSpan);
    function value=span(points)
        center=(min(points,[],1)+max(points,[],1))/2;points=points-center;
        value=max(max(abs(points*right'))/aspect,max(abs(points*up')));
    end
end
