
clc
clear all
close all

hazy_image = imread('22.jpg');

% Convert the input image to double precision
image = im2double(hazy_image);

% Estimate the dark channel of the hazy image
dark_channel = min(image, [], 3);

% Define the patch size for dark channel prior calculation
patch_size = 15;

% Compute the dark channel prior
dark_channel_prior = imerode(dark_channel, strel('square', patch_size));

% Estimate the atmospheric light
percentage = 0.001; % Percentage of brightest pixels to consider
num_pixels = numel(dark_channel);
num_top_pixels = round(num_pixels * percentage);
sorted_dark_channel = sort(dark_channel_prior(:), 'descend');
atmospheric_light = mean(sorted_dark_channel(1:num_top_pixels));

% Estimate the transmission map
transmission_map = 1 - dark_channel ./ atmospheric_light;

% Clip transmission map to avoid artifacts
transmission_map = max(transmission_map, 0.1);

% Dehaze the image using the estimated transmission map and atmospheric light
dehazed_image = zeros(size(image));
for i = 1:3
    dehazed_image(:, :, i) = (image(:, :, i) - atmospheric_light) ./ transmission_map + atmospheric_light;
end

% Clip dehazed image to [0, 1] range
dehazed_image = max(min(dehazed_image, 1), 0);
dehaze=imreducehaze(image);

% Display the hazy image and dehazed image side by side
figure;
subplot(1, 2, 1);
imshow(hazy_image);
title('Hazy Image');
subplot(1, 2, 2);
imshow(dehaze);
title('Dehazed Image');
