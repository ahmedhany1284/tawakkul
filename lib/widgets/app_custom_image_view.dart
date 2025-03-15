import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

extension ImageTypeExtension on String {
  ImageType get imageType {
    if (startsWith('http')) {
      return ImageType.network;
    } else if (endsWith('.svg')) {
      return ImageType.svg;
    } else if (endsWith('.webp')) {
      return ImageType.webp;
    } else if (startsWith('file://')) {
      return ImageType.file;
    } else {
      return ImageType.png;
    }
  }
}

enum ImageType { svg, png, network, file, webp, unknown, jpg }

// ignore_for_file: must_be_immutable
class AppCustomImageView extends StatelessWidget {
  const AppCustomImageView({
    super.key,
    this.imagePath,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.height,
    this.width,
    this.color,
    this.fit,
    this.alignment,
    this.onTap,
    this.radius,
    this.margin,
    this.border,
    this.placeHolder = 'assets/images/placeholder.webp',
    this.enableImageViewer = false,
  });

  final String? imagePath;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
  final double? height;
  final double? width;
  final Color? color;
  final BoxFit? fit;
  final String placeHolder;
  final Alignment? alignment;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? radius;
  final BoxBorder? border;
  final bool enableImageViewer;

  void _handleImageTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (!enableImageViewer || imagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerPage(imageUrl: imagePath!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return alignment != null ? Align(alignment: alignment!, child: _buildWidget(context)) : _buildWidget(context);
  }

  Widget _buildWidget(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: InkWell(
        onTap: () => _handleImageTap(context),
        child: _buildCircleImage(),
      ),
    );
  }

  /// Previous methods remain the same...
  Widget _buildCircleImage() {
    if (radius != null) {
      return ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: _buildImageWithBorder(),
      );
    } else {
      return _buildImageWithBorder();
    }
  }

  Widget _buildImageWithBorder() {
    if (border != null) {
      return Container(
        decoration: BoxDecoration(
          border: border,
          borderRadius: radius,
        ),
        child: _buildImageView(),
      );
    } else {
      return _buildImageView();
    }
  }

  Widget _buildImageView() {
    if (icon != null) {
      return Icon(
        icon,
        size: iconSize ?? height,
        color: iconColor ?? color,
      );
    }

    if (imagePath != null) {
      switch (imagePath!.imageType) {
        case ImageType.svg:
          return SizedBox(
            height: height,
            width: width,
            child: SvgPicture.asset(
              imagePath!,
              height: height,
              width: width,
              fit: fit ?? BoxFit.contain,
              colorFilter: color != null ? ColorFilter.mode(color ?? Colors.transparent, BlendMode.srcIn) : null,
            ),
          );
        case ImageType.file:
          return Image.file(
            File(imagePath!),
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
          );
        case ImageType.webp:
          return Image.asset(
            imagePath!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
          );
        case ImageType.network:
          return CachedNetworkImage(
            height: height,
            width: width,
            fit: fit,
            imageUrl: imagePath!,
            color: color,
            placeholder: (context, url) => SizedBox(
              height: 30,
              width: 30,
              child: LinearProgressIndicator(
                color: Colors.grey.shade200,
                backgroundColor: Colors.grey.shade100,
              ),
            ),
            errorWidget: (context, url, error) => Image.asset(
              placeHolder,
              height: height,
              width: width,
              fit: fit ?? BoxFit.cover,
            ),
          );
        case ImageType.png:
        default:
          return Image.asset(
            imagePath!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                placeHolder,
                height: height,
                width: width,
                fit: fit ?? BoxFit.cover,
              );
            },
          );
      }
    }
    return const SizedBox();
  }
}

// Image Viewer Page
class ImageViewerPage extends StatelessWidget {
  final String imageUrl;

  const ImageViewerPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: imageUrl.imageType == ImageType.network
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.error,
                      color: Colors.white,
                    ),
                  )
                : Image.asset(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
