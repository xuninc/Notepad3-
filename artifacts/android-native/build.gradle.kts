// Top-level build file. Plugins are declared here with `apply false` so that
// each module that needs them applies them itself with the same version.

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
