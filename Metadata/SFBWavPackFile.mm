//
// Copyright (c) 2006 - 2022 Stephen F. Booth <me@sbooth.org>
// Part of https://github.com/sbooth/SFBAudioEngine
// MIT license
//

#import <memory>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

#import <taglib/tfilestream.h>
#import <taglib/wavpackfile.h>

#pragma clang diagnostic pop

#import "SFBWavPackFile.h"

#import "AddAudioPropertiesToDictionary.h"
#import "NSError+SFBURLPresentation.h"
#import "SFBAudioMetadata+TagLibAPETag.h"
#import "SFBAudioMetadata+TagLibID3v1Tag.h"

SFBAudioFileFormatName const SFBAudioFileFormatNameWavPack = @"org.sbooth.AudioEngine.File.WavPack";

@implementation SFBWavPackFile

+ (void)load
{
	[SFBAudioFile registerSubclass:[self class]];
}

+ (NSSet *)supportedPathExtensions
{
	return [NSSet setWithObject:@"wv"];
}

+ (NSSet *)supportedMIMETypes
{
	return [NSSet setWithArray:@[@"audio/wavpack", @"audio/x-wavpack"]];
}

+ (SFBAudioFileFormatName)formatName
{
	return SFBAudioFileFormatNameWavPack;
}

- (BOOL)readPropertiesAndMetadataReturningError:(NSError **)error
{
	TagLib::FileStream stream(self.url.fileSystemRepresentation, true);
	if(!stream.isOpen()) {
		if(error)
			*error = [NSError SFB_errorWithDomain:SFBAudioFileErrorDomain
											 code:SFBAudioFileErrorCodeInputOutput
					descriptionFormatStringForURL:NSLocalizedString(@"The file “%@” could not be opened for reading.", @"")
											  url:self.url
									failureReason:NSLocalizedString(@"Input/output error", @"")
							   recoverySuggestion:NSLocalizedString(@"The file may have been renamed, moved, deleted, or you may not have appropriate permissions.", @"")];
		return NO;
	}

	TagLib::WavPack::File file(&stream);
	if(!file.isValid()) {
		if(error)
			*error = [NSError SFB_errorWithDomain:SFBAudioFileErrorDomain
											 code:SFBAudioFileErrorCodeInvalidFormat
					descriptionFormatStringForURL:NSLocalizedString(@"The file “%@” is not a valid WavPack file.", @"")
											  url:self.url
									failureReason:NSLocalizedString(@"Not a WavPack file", @"")
							   recoverySuggestion:NSLocalizedString(@"The file's extension may not match the file's type.", @"")];
		return NO;
	}

	NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionaryWithObject:@"WavPack" forKey:SFBAudioPropertiesKeyFormatName];
	if(file.audioProperties()) {
		auto properties = file.audioProperties();
		SFB::Audio::AddAudioPropertiesToDictionary(properties, propertiesDictionary);

		if(properties->bitsPerSample())
			propertiesDictionary[SFBAudioPropertiesKeyBitDepth] = @(properties->bitsPerSample());
		if(properties->sampleFrames())
			propertiesDictionary[SFBAudioPropertiesKeyFrameLength] = @(properties->sampleFrames());
	}

	SFBAudioMetadata *metadata = [[SFBAudioMetadata alloc] init];
	if(file.hasID3v1Tag())
		[metadata addMetadataFromTagLibID3v1Tag:file.ID3v1Tag()];

	if(file.hasAPETag())
		[metadata addMetadataFromTagLibAPETag:file.APETag()];

	self.properties = [[SFBAudioProperties alloc] initWithDictionaryRepresentation:propertiesDictionary];
	self.metadata = metadata;
	return YES;
}

- (BOOL)writeMetadataReturningError:(NSError **)error
{
	TagLib::FileStream stream(self.url.fileSystemRepresentation);
	if(!stream.isOpen()) {
		if(error)
			*error = [NSError SFB_errorWithDomain:SFBAudioFileErrorDomain
											 code:SFBAudioFileErrorCodeInputOutput
					descriptionFormatStringForURL:NSLocalizedString(@"The file “%@” could not be opened for writing.", @"")
											  url:self.url
									failureReason:NSLocalizedString(@"Input/output error", @"")
							   recoverySuggestion:NSLocalizedString(@"The file may have been renamed, moved, deleted, or you may not have appropriate permissions.", @"")];
		return NO;
	}

	TagLib::WavPack::File file(&stream);
	if(!file.isValid()) {
		if(error)
			*error = [NSError SFB_errorWithDomain:SFBAudioFileErrorDomain
											 code:SFBAudioFileErrorCodeInvalidFormat
					descriptionFormatStringForURL:NSLocalizedString(@"The file “%@” is not a valid WavPack file.", @"")
											  url:self.url
									failureReason:NSLocalizedString(@"Not a WavPack file", @"")
							   recoverySuggestion:NSLocalizedString(@"The file's extension may not match the file's type.", @"")];
		return NO;
	}

	// ID3v1 tags are only written if present, but an APE tag is always written

	if(file.hasID3v1Tag())
		SFB::Audio::SetID3v1TagFromMetadata(self.metadata, file.ID3v1Tag());

	SFB::Audio::SetAPETagFromMetadata(self.metadata, file.APETag(true));

	if(!file.save()) {
		if(error)
			*error = [NSError SFB_errorWithDomain:SFBAudioFileErrorDomain
											 code:SFBAudioFileErrorCodeInputOutput
					descriptionFormatStringForURL:NSLocalizedString(@"The file “%@” could not be saved.", @"")
											  url:self.url
									failureReason:NSLocalizedString(@"Unable to write metadata", @"")
							   recoverySuggestion:NSLocalizedString(@"The file's extension may not match the file's type.", @"")];
		return NO;
	}


	return YES;
}

@end
