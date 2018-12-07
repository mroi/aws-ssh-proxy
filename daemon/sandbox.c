#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <sysexits.h>

extern int sandbox_init_with_parameters(const char *profile, uint64_t flags, const char *const parameters[], char **errorbuf);

static const char profile[] =
	"(version 1)\n"
	"(deny default)\n"
	"(debug deny)\n"
	"(import \"system.sb\")\n"
	"(define bundle-path (param \"BUNDLE_PATH\"))\n"
	"(allow file-read-metadata)\n"
	"(allow file-read* (subpath bundle-path))\n"
	"(allow file-read* (require-all (file-mode #o0004)(require-not (subpath \"/Users\"))))\n"
	"(allow file-read* (regex #\"^/Users/[^/]+/Library/Preferences/(ByHost/)?(\\.GlobalPreferences|com\\.apple\\.security)\\..*plist$\"))\n"
	"(allow file-read* file-write* (subpath \"/private/var/folders\"))\n"
	"(allow ipc-posix-shm* (ipc-posix-name \"com.apple.AppleDatabaseChanged\"))\n"
	"(allow mach-lookup (global-name \"com.apple.CoreServices.coreservicesd\"))\n"
	"(allow mach-lookup (global-name \"com.apple.SecurityServer\"))\n"
	"(allow mach-lookup (global-name \"com.apple.lsd.mapdb\"))\n"
	"(allow mach-lookup (global-name-regex #\"^com\\.apple\\.distributed_notifications\"))\n"
	"(allow user-preference-read (preference-domain \"kCFPreferencesAnyApplication\"))\n"
	"(allow user-preference-read (preference-domain \"com.apple.security\"))\n"
	"(allow network-outbound (remote ip) (subpath \"/private/var/run\"))\n"
	"(system-network)\n";

void sandbox(const char *bundle_path)
{
	char *error;
	const char *params[3];

	params[0] = "BUNDLE_PATH";
	params[1] = bundle_path;
	params[2] = NULL;

	if (sandbox_init_with_parameters(profile, 0, params, &error) != 0) {
		puts(error);
		exit(EX_OSERR);
	}
}