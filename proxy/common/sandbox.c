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
	"(allow file-read-metadata)\n"
	"(allow file-read* (subpath (param \"BUNDLE_PATH\")))\n"
	"(allow file-read* (literal (string-append (param \"HOME\") \"/.CFUserTextEncoding\")))\n"
	"(allow file-read* (require-all (file-mode #o0004)(require-not (subpath \"/Users\"))))\n"
	// required access to preferences
	"(allow user-preference-read (preference-domain \"kCFPreferencesAnyApplication\"))\n"
	"(allow user-preference-read (preference-domain \"com.apple.security\"))\n"
	"(allow file-read* (regex #\"^/Users/[^/]+/Library/Preferences/(ByHost/)?(\\.GlobalPreferences|com\\.apple\\.security)\\..*plist$\"))\n"
	// ancient calls to CSSM access the MDS database in /private/var/folders
	"(allow file-read* file-write* (subpath \"/private/var/folders\"))\n"
	"(allow ipc-posix-shm* (ipc-posix-name \"com.apple.AppleDatabaseChanged\"))\n"
	// URLSession checks some filesystem properties when initializing the HSTS store
	"(allow mach-lookup (global-name \"com.apple.CoreServices.coreservicesd\"))\n"
	// certificate validation
	"(allow mach-lookup (global-name \"com.apple.SecurityServer\"))\n"
	// UTI enumeration due to MIME type in HTTPURLResponse
	"(allow mach-lookup (global-name \"com.apple.lsd.mapdb\"))\n"
	// system notification bus
	"(allow mach-lookup (global-name-regex #\"^com\\.apple\\.distributed_notifications\"))\n"
	// networking and related daemon sockets (like mDNSResponder)
	"(allow network-outbound (remote ip) (subpath \"/private/var/run\"))\n"
	"(system-network)\n";

void sandbox(const char *home, const char *bundle_path)
{
#ifdef __APPLE__
	char *error;
	const char *params[5];

	params[0] = "HOME";
	params[1] = home;
	params[2] = "BUNDLE_PATH";
	params[3] = bundle_path;
	params[4] = NULL;

	if (sandbox_init_with_parameters(profile, 0, params, &error) != 0) {
		puts(error);
		exit(EX_OSERR);
	}

#elif __linux__
	(void)home;
	(void)bundle_path;
#endif
}
