%Author: @Benjamin Meene

function im2d = projection_to_2D(planes, depth_values, vanishing_point, focal_length, rotation_angles, translation)
%project a 3D RGB image onto a 2D pixel plane including rotation,
%translation of camera
%   INPUT: a 3-dimensional (rgb or greyscale) image, 
%   a vector the 4 depth values of the side planes, 
%   the coordinates of the vanishing point (x,y),
%   the camera focal length, 
%   the 3 rotation angles around the axis,
%   a column vector of translation of the camera from vanishing point
%   OUTPUT: the projected 2-dimensional rgb image.


%% preparation:
% plane order: planes = {rearplane, leftplane, ceilingplane, rightplane, bottomplane}

dimensions = {3, 1, 2, 1, 2}; % the directions to which planes are orthogonal (1: X, 2: Y, 3: Z)

[maxY,maxX,channels] = size(planes{1}); % get 3D model x and y size from rear plane
maxZ = max(depth_values); % maximum depth among all side planes

sz_x_2d = round(2*maxX);
sz_y_2d = round(2*maxY);

% init 2D image:
im2d = nan(sz_y_2d,sz_x_2d,channels);

%% setup camera and parameters:
% camera:
o_x = sz_x_2d/2; % 2D pixel coordinate system origin x
o_y = sz_y_2d/2; % 2D pixel coordinate system origin y

% homography:
Rx = [1,0,0;0,cos(rotation_angles(1)),-sin(rotation_angles(1));0,sin(rotation_angles(1)),cos(rotation_angles(1))];
Ry = [cos(rotation_angles(2)),0,sin(rotation_angles(2));0,1,0;-sin(rotation_angles(2)),0,cos(rotation_angles(2))];
Rz = [cos(rotation_angles(3)),-sin(rotation_angles(3)),0;sin(rotation_angles(3)),cos(rotation_angles(3)),0;0,0,1];

R = Rx*Ry*Rz; % complete rotation matrix in all directions

T_orig = [translation(1);translation(2);translation(3)]  - R' * [-vanishing_point(1);-vanishing_point(2);focal_length]; % move camera center/coordinate system back by f -> movement by maxZ is already incorporated in the coordinate creatrion for the planes % - maxZ + focal_length];

iRange = 1:length(planes);

%% iterate over planes:
for i = iRange       
    %% determine size of 3D image:
    thisplane = double(planes{i});
    [sz_dim1, sz_dim2, ~] = size(thisplane);
    offset_dim1 = 0;
    offset_dim2 = 0;
    
    %% projection to 2D:
    % enhance input image for better quality when stretching planes:
    enhance = 2; % enhance image planes by factor - let <= 4 for performance/speed
    if enhance>1
        thisplane = repelem(thisplane,enhance,enhance); %repeat every element enhance times in all directions: im3d(1,1,1) => im3d(1:enhance,1:enhance,1:enhance)
    end
    % update T because of enhancement:
    T = enhance*T_orig;
    % create camera intrinsics object for projection:
    intr = cameraIntrinsics([focal_length,focal_length], [o_x,o_y], enhance*[sz_x_2d,sz_y_2d]);
    
    % create correct plane axis values in 3D:
    if dimensions{i} == 1
        % normal to X-axis:
        Yrange = 1:enhance*sz_dim1;
        Zrange = 1:enhance*sz_dim2;
        if i == 2
            % left plane
            Xrange = 1;
            offset_dim2 = enhance*(maxZ - sz_dim2);
        else
            % right plane
            Xrange = enhance*maxX;
            offset_dim2 = enhance*(maxZ - sz_dim2);
            thisplane = fliplr(thisplane); % correct orientation of right plane (input is flipped)
        end
        [Yrange,Zrange] = meshgrid(Yrange + offset_dim1,Zrange + offset_dim2);
        Yrange = reshape(Yrange,numel(Yrange),1);
        Zrange = reshape(Zrange,numel(Yrange),1);
        Xrange = Xrange*ones(numel(Yrange),1);
    elseif dimensions{i} == 2
        % normal to Y-axis:
        Xrange = 1:enhance*sz_dim2;
        Zrange = 1:enhance*sz_dim1;
        if i == 3
            % ceiling plane
            Yrange = 1;
            offset_dim1 = enhance*(maxZ - sz_dim1);
        else
            % bottom plane
            Yrange = enhance*maxY;
            offset_dim1 = enhance*(maxZ - sz_dim1);
            thisplane = flipud(thisplane); % correct orientation of bottom plane (input is flipped)
        end
        [Xrange,Zrange] = meshgrid(Xrange + offset_dim2,Zrange + offset_dim1);
        Xrange = reshape(Xrange,numel(Xrange),1);
        Zrange = reshape(Zrange,numel(Xrange),1);
        Yrange = Yrange*ones(numel(Xrange),1);
    elseif dimensions{i} == 3
        % normal to Z-axis:
        % rear plane
        Yrange = 1:enhance*sz_dim1;
        Xrange = 1:enhance*sz_dim2;

        [Xrange,Yrange] = meshgrid(Xrange + offset_dim2,Yrange + offset_dim2);
        Xrange = reshape(Xrange,numel(Xrange),1);
        Yrange = reshape(Yrange,numel(Xrange),1);
        Zrange = enhance*maxZ*ones(numel(Xrange),1); % always maxZ (rear plane)
    end
    X = Xrange;
    Y = Yrange;
    Z = Zrange;

    % create correct plane axis values for 2D planes in 3D:
    if dimensions{i} == 1
        % normal to X-axis:
        index = [Y-offset_dim1,Z-offset_dim2];
    elseif dimensions{i} == 2
        % normal to Y-axis:
        index = [Z-offset_dim1,X-offset_dim2];
    elseif dimensions{i} == 3
        % normal to Z-axis:
        index = [Y + offset_dim1,X + offset_dim2];
    end

    % actual pixel projection calculation:
    [pts2d, validindex] = worldToImage(intr, R, -T, ([X,Y,Z]-[1,1,0]));% substract [1;1;0] because of matlab beginning arrays with 1; Z coordinate cannot be 0! 
    % round and extract only valid indices (within pixel plane):
    x_2d = round(pts2d(validindex,1));
    y_2d = round(pts2d(validindex,2));
    
    % check if new plane will be covering an existing plane
    % or if pixel projection is not as it should (e.g. out of range/distorted):
    % if yes -> do not project
    if dimensions{i} == 1
        % normal to X-axis:
        change = diff(x_2d);
        change = change(change~=0); % get difference between all projected x indices which are within pixel plane
        % do not plot current plane if none of projected pixels is on pixel
        % plane ( -> empty vector):
        if size(x_2d,1) == 0
            continue;
        end
        if i == 2
            % left plane - criterion: do not plot if 2D x-values decrease (if
            % at most 10 increase)
            if sum((change <= 5) .* (change < 0)) < 10
                continue;
            end
            % do not plot if projection is right of any other plane
            if x_2d(1) > maxX
                continue;
            end
        else
            % right plane - criterion: do not plot if 2D x-values increase (if
            % at most 10 decrease)
            % (since plane is lr flipped)
            if sum((change >= -5) .* (change < 0)) < 10
                continue;
            end
            % do not plot if projection is left of any other plane
            if x_2d(1) < maxX
                continue;
            end
        end
    elseif dimensions{i} == 2
        % normal to Y-axis:
        change = diff(y_2d);
        change = change(change~=0); % get difference between all projected y indices which are within pixel plane
        % do not plot current plane if none of projected pixels is on pixel
        % plane ( -> empty vector):
        if size(y_2d,1) == 0
            continue;
        end
        if i == 3
            % ceiling plane - criterion: do not plot if 2D y-values decrease (if
            % at most 10 increase)
            if sum((change <= 5) .* (change > 0)) < 10
                continue;
            end
        else
            % bottom plane - criterion: do not plot if 2D y-values increase (if
            % at most 10 decrease)
            % (since plane is ud flipped)
            if sum((change >= -5) .* (change < 0)) < 10
                continue;
            end
        end        
    end
    
    % set color values for projected pixels:
    part = 1; 
    index = round(index(validindex,:));
    while part < length(x_2d)
        if ((x_2d(part)*y_2d(part) > 0) && (x_2d(part) <= sz_x_2d) && (y_2d(part) <= sz_y_2d))
            im2d(y_2d(part),x_2d(part),:) = thisplane(index(part,1),index(part,2),:);
        end
        part = part+1;
    end
end
% convert back to uint8:
im2d = uint8(im2d);
end
