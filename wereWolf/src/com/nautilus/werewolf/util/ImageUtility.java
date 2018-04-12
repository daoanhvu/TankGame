package com.nautilus.werewolf.util;

import java.awt.Image;
import java.awt.Color;
import java.awt.geom.AffineTransform;
import java.awt.image.*;
import java.awt.AlphaComposite;
import java.awt.Graphics2D;
import java.awt.Toolkit;


/**
 alpha channel
 The Color class stores colours internally as a 32-bit integer,
 8 bits each of red, green, blue and alpha, each value 0..255.
 Alpha measures opacity. 0=transparent 255=opaque. The default for the alpha value is 255,
 completely opaque.

 The combined ARGB value consists of the alpha component in bits 24-31,
 the red component in bits 16-23, the green component in bits 8-15, and the blue component in
 bits 0-7 where bit 0 is the least significant bit.

 Creating a colour with an alpha component.
 Note order of parameters is RGBA, not ARGB as they are internally.
 Dark orange is #ff8c00 in HTML.

 Color almostTransparentDarkOrange = new Color( 0xff red ,
 0x8c  green,
 0x00  blue,
 0x1f  alpha);
 */

public final class ImageUtility{

    public static BufferedImage scaleImage(BufferedImage input, double scale) {
        int h2 = (int) (input.getHeight() * scale);
        int w2 = (int) (input.getWidth() * scale );
        BufferedImage output = new BufferedImage(w2, h2, input.getType());
        AffineTransform affineScale = AffineTransform.getScaleInstance(scale, scale);
        AffineTransformOp scaleOp = new AffineTransformOp(affineScale, AffineTransformOp.TYPE_BILINEAR);
        scaleOp.filter(input, output);
        return output;
    }

    public static BufferedImage scaleToPreferHeight(BufferedImage input, int preferHeight) {
        double scale = (preferHeight * 1.0 ) / input.getHeight();
        int w2 = (int) (input.getWidth() * scale );
        BufferedImage output = new BufferedImage(w2, preferHeight, input.getType());
        AffineTransform affineScale = AffineTransform.getScaleInstance(scale, scale);
        AffineTransformOp scaleOp = new AffineTransformOp(affineScale, AffineTransformOp.TYPE_BILINEAR);
        scaleOp.filter(input, output);
        return output;
    }

    public static BufferedImage scaleToSize(BufferedImage input, int toWidth, int toHeight) {
        double scaleH = (toHeight * 1.0 ) / input.getHeight();
        double scaleW = (toWidth * 1.0 ) / input.getWidth();
        BufferedImage output = new BufferedImage(toWidth, toHeight, input.getType());
        AffineTransform affineScale = AffineTransform.getScaleInstance(scaleW, scaleH);
        AffineTransformOp scaleOp = new AffineTransformOp(affineScale, AffineTransformOp.TYPE_BILINEAR);
        scaleOp.filter(input, output);
        return output;
    }

    /**
     @usage:
     m_images = new BufferedImage[3];
     m_images[0] = ImageIO.read(new File("E:/Documents/images/map.png"));
     m_images[1] = ImageIO.read(new File("E:/Documents/images/mapMask3.png"));
     Image transpImg = TransformGrayToTransparency(m_images[1]);
     m_images[2] = ApplyTransparency(m_images[0], transpImg);
     */
    public static Image transferToTransparency(BufferedImage inputImage, final Color fromC,
                                               final Color toC){

        final int r1 = fromC.getRed();
        final int g1 = fromC.getGreen();
        final int b1 = fromC.getBlue();

        final int r2 = toC.getRed();
        final int g2 = toC.getGreen();
        final int b2 = toC.getBlue();

        ImageFilter imgFilter = new RGBImageFilter(){
            public final int filterRGB(int x, int y, int rgb){
                int r = (rgb & 0x00ff0000) >> 16;
                int g = (rgb & 0x0000ff00) >> 8;
                int b = (rgb & 0x000000ff);

                if( (r>= r1 && r<=r2) && (g>= g1 && g<=g2) && (b>=b1 && b<=b2) ){
                    //full transparent
                    return (rgb & 0x00ffffff);
                }

                return rgb;
            }
        };

        ImageProducer ip = new FilteredImageSource(inputImage.getSource(), imgFilter);
        return Toolkit.getDefaultToolkit().createImage(ip);
    }

    public static BufferedImage applyTransparency(BufferedImage inputImage, final Color fromC,
                                                  final Color toC){
        BufferedImage dest;
        Image image = transferToTransparency(inputImage, fromC, toC);
        dest = new BufferedImage(
                image.getWidth(null), image.getHeight(null), BufferedImage.TYPE_INT_ARGB);
        Graphics2D g2 = dest.createGraphics();
        g2.drawImage(image, 0, 0, null);
        g2.dispose();
        return dest;
    }

    public void applyGrayscaleMaskToAlpha(BufferedImage image, BufferedImage mask){
        int width = image.getWidth();
        int height = image.getHeight();

        int[] imagePixels = image.getRGB(0, 0, width, height, null, 0, width);
        int[] maskPixels = mask.getRGB(0, 0, width, height, null, 0, width);

        for (int i = 0; i < imagePixels.length; i++){
            int color = imagePixels[i] & 0x00ffffff; // Mask preexisting alpha
            int alpha = maskPixels[i] << 24; // Shift green to alpha
            imagePixels[i] = color | alpha;
        }

        image.setRGB(0, 0, width, height, imagePixels, 0, width);
    }

    private static int[][] convertTo2DWithoutUsingGetRGB(BufferedImage image) {
        final byte[] pixels = ((DataBufferByte) image.getRaster().getDataBuffer()).getData();
        final int width = image.getWidth();
        final int height = image.getHeight();
        final boolean hasAlphaChannel = image.getAlphaRaster() != null;

        int[][] result = new int[height][width];
        if (hasAlphaChannel) {
            final int pixelLength = 4;
            for (int pixel = 0, row = 0, col = 0; pixel < pixels.length; pixel += pixelLength) {
                int argb = 0;
                argb += (((int) pixels[pixel] & 0xff) << 24); // alpha
                argb += ((int) pixels[pixel + 1] & 0xff); // blue
                argb += (((int) pixels[pixel + 2] & 0xff) << 8); // green
                argb += (((int) pixels[pixel + 3] & 0xff) << 16); // red
                result[row][col] = argb;
                col++;
                if (col == width) {
                    col = 0;
                    row++;
                }
            }
        } else {
            final int pixelLength = 3;
            for (int pixel = 0, row = 0, col = 0; pixel < pixels.length; pixel += pixelLength) {
                int argb = 0;
                argb += -16777216; // 255 alpha
                argb += ((int) pixels[pixel] & 0xff); // blue
                argb += (((int) pixels[pixel + 1] & 0xff) << 8); // green
                argb += (((int) pixels[pixel + 2] & 0xff) << 16); // red
                result[row][col] = argb;
                col++;
                if (col == width) {
                    col = 0;
                    row++;
                }
            }
        }
        return result;
    }

    /**
     *
     * @param transp opacity value MUST be [0.0f -> 1.0f]
     * */
    public static Image makeTransparent(final BufferedImage im, float transp) {
        final int alphaValue = Math.round(255.0f * transp);

        final ImageFilter filter = new RGBImageFilter() {
            public final int filterRGB(final int x, final int y, final int rgb) {
                return (0x00FFFFFF | (alphaValue << 24)) & rgb;
            }
        };

        final ImageProducer ip = new FilteredImageSource(im.getSource(), filter);
        return Toolkit.getDefaultToolkit().createImage(ip);
    }
}