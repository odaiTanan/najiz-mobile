# Safety fallback: if any transitive SLF4J binder class is absent, don't fail minify.
-dontwarn org.slf4j.impl.StaticLoggerBinder
