//
//  CGBlendMode.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


/// Compositing operations for images.
///
/// These blend modes determine how source colors are combined with destination
/// colors when drawing in a graphics context.
public enum CGBlendMode: Int32, Sendable {
    /// Paints the source image samples over the background image samples.
    case normal = 0

    /// Multiplies the source image samples with the background image samples.
    /// This results in colors that are at least as dark as either sample.
    case multiply = 1

    /// Multiplies the inverse of the source image samples with the inverse of
    /// the background image samples, resulting in colors that are at least as
    /// light as either sample.
    case screen = 2

    /// Either multiplies or screens the source image samples with the
    /// background image samples, depending on the background color.
    case overlay = 3

    /// Creates the composite image samples by choosing the darker samples
    /// (from either the source image or the background).
    case darken = 4

    /// Creates the composite image samples by choosing the lighter samples
    /// (from either the source image or the background).
    case lighten = 5

    /// Brightens the background image samples to reflect the source image samples.
    case colorDodge = 6

    /// Darkens the background image samples to reflect the source image samples.
    case colorBurn = 7

    /// Either darkens or lightens colors, depending on the source image
    /// sample color.
    case softLight = 8

    /// Either multiplies or screens colors, depending on the source image
    /// sample color.
    case hardLight = 9

    /// Subtracts either the source image sample color from the background image
    /// sample color, or the reverse, depending on which sample has the greater
    /// brightness value.
    case difference = 10

    /// Produces an effect similar to that produced by `difference`, but with
    /// lower contrast.
    case exclusion = 11

    /// Uses the hue of the source image with the saturation and luminosity of
    /// the background image.
    case hue = 12

    /// Uses the saturation of the source image with the hue and luminosity of
    /// the background image.
    case saturation = 13

    /// Uses the hue and saturation of the source image with the luminosity of
    /// the background image.
    case color = 14

    /// Uses the luminosity of the source image with the hue and saturation of
    /// the background image.
    case luminosity = 15

    // Porter-Duff blend modes

    /// Clears the background to transparent.
    case clear = 16

    /// Copies the source to the destination.
    case copy = 17

    /// Copies the source over the destination.
    case sourceIn = 18

    /// Copies the source where the destination is not transparent.
    case sourceOut = 19

    /// Draws the source on top of the destination.
    case sourceAtop = 20

    /// Copies the destination over the source.
    case destinationOver = 21

    /// Copies the destination where the source is not transparent.
    case destinationIn = 22

    /// Copies the destination where the source is transparent.
    case destinationOut = 23

    /// Draws the destination on top of the source.
    case destinationAtop = 24

    /// Exclusive OR of the source and destination.
    case xor = 25

    /// Adds the source and destination pixel values to give a sum.
    case plusDarker = 26

    /// Adds the source and destination pixel values, saturating at the
    /// maximum value.
    case plusLighter = 27
}

