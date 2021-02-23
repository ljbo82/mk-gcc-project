# Copyright 2021 Leandro José Britto de Oliveira
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifeq ($(PROJ_NAME),)
    $(error Missing PROJ_NAME)
endif

ifneq (1, $(words $(PROJ_NAME)))
    $(error PROJ_NAME cannot have spaces)
endif

PROJ_VERSION ?= 0.1.0
ifeq ($(shell sh -c "echo $(PROJ_VERSION) | grep -oP '[0-9]+\.[0-9]+\.[0-9]+.*'"), )
    $(error Invalid PROJECT_VERSION: $(PROJECT_VERSION))
endif
projVersionMajor := $(shell echo $(PROJ_VERSION) | cut -d'.' -f1)
projVersionMinor := $(shell echo $(PROJ_VERSION) | cut -d'.' -f2)
projVersionPatch := $(shell echo $(PROJ_VERSION) | cut -d'.' -f3-)

PROJ_TYPE ?= app
ifneq ($(PROJ_TYPE), app)
    ifneq ($(PROJ_TYPE), lib)
        $(error Unsupported PROJ_TYPE: $(PROJ_TYPE))
    else
        LIB_TYPE ?= shared
        ifneq ($(LIB_TYPE), shared)
            ifneq ($(LIB_TYPE), static)
                $(error Unsupported LIB_TYPE: $(LIB_TYPE))
            endif
        endif
    endif
endif

DEBUG ?= 0
ifneq ($(DEBUG), 0)
    ifneq ($(DEBUG), 1)
        $(error Invalid value for DEBUG: $(DEBUG))
    endif
endif

V ?= 0
ifneq ($(V), 0)
    ifneq ($(V), 1)
        $(error ERROR: Invalid value for V: $(V))
    endif
endif

ifeq ($(V), 0)
    v := @
    nl :=
else
    v :=
    nl := \n
endif

BUILD_BASE ?= build
ifeq ($(BUILD_DIR), )
    ifneq ($(HOST), )
        buildDir := $(BUILD_BASE)/$(HOST)
    else
        buildDir := $(BUILD_BASE)
    endif
else
    buildDir := $(BUILD_DIR)
endif

DIST_BASE ?= dist
ifeq ($(DIST_DIR), )
    ifneq ($(HOST), )
        distDir := $(DIST_BASE)/$(HOST)
    else
        distDir := $(DIST_BASE)
    endif
else
    distDir := $(DIST_DIR)
endif

ifneq ($(wildcard src), )
    srcDirs += src
endif
srcDirs += $(SRC_DIRS)

ifneq ($(wildcard include), )
    includeDirs += include
    ifeq ($(PROJ_TYPE, lib)
        postDist += mkdir -p $(distDir); cp -a -R include $(distDir);
    endif
endif
includeDirs += $(INCLUDE_DIRS)

ifeq ($(DEBUG), 1)
    objSuffix := .dbg.o
else
    objSuffix := .o
endif
srcFiles := $(strip $(foreach srcDir, $(srcDirs), $(shell find $(srcDir) -type f -name *.c -or -name *.cpp -or -name *.S 2> /dev/null)))
objFiles := $(srcFiles:%=$(buildDir)/%$(objSuffix))
deps := $(objFiles:.o=.d)

ifeq ($(DEBUG), 1)
    artifactNameSuffix := _d
endif
artifactName := $(PROJ_NAME)$(artifactNameSuffix)
ifeq ($(PROJ_TYPE), lib)
    artifactName := lib$(artifactName)
    postDist += mkdir -p $(distDir)/lib;
    ifeq ($(LIB_TYPE), static)
        artifactBaseName := $(artifactName)$(projVersionMajor).a
        postDist += cp -a $(buildDir)/*.a* $(distDir)/lib;
    else
        artifactBaseName := $(artifactName)$(projVersionMajor).so
        postDist += cp -a $(buildDir)/*.so* $(distDir)/lib;
    endif
    artifactName := $(artifactBaseName).$(projVersionMajor).$(projVersionMinor).$(projVersionPatch)
    postBuild := cd $(buildDir); ln -sf $(artifactName) $(artifactBaseName);
else
    postDist += mkdir -p $(distDir)/bin; cp -a $(buildDir)/$(artifactName) $(distDir)/bin;
endif
buildArtifact := $(buildDir)/$(artifactName)

cFlags += -Wall
cxxFlags += -Wall
ifeq ($(DEBUG), 1)
    cFlags += -g3
    cxxFlags += -g3
endif

includeFlags += $(strip $(foreach srcDir, $(srcDirs), -I$(srcDir)))
includeFlags += $(strip $(foreach includeDir, $(includeDirs), -I$(includeDir)))

ifeq ($(DEBUG), 1)
    cFlags += -DDEBUG=1
    cxxFlags += -DDEBUG=1
endif
ifeq ($(PROJ_TYPE), lib)
    ifeq ($(LIB_TYPE), shared)
        cFlags += -fPIC
        cxxFlags += -fPIC
    endif
endif

ifeq ($(DEBUG), 1)
    asFlags += --gstabs+
endif

ifeq ($(PROJ_TYPE), lib)
    ifeq ($(LIB_TYPE), shared)
        ldFlags += -shared
    endif
endif

arFlags += rcs

cppProject := $(strip $(foreach srcDir, $(srcDirs), $(shell find $(srcDir) -type f -name *.cpp 2> /dev/null)))
ifeq ($(cppProject), )
    cppProject = $(strip $(foreach includeDir, $(includeDirs), $(shell find $(includeDir) -type f -name *.hpp 2> /dev/null)))
endif

ifeq ($(cppProject), )
    cppProject := 0
else
    cppProject := 1
endif

ifeq ($(cppProject), 0)
    # Pure C project
    LD := $(CC)
else
    # C/C++ project
    LD := $(CXX)
endif

ifneq ($(GCC_PREFIX), )
    gccPrefix := $(GCC_PREFIX)-
endif
CC  := $(gccPrefix)$(CC)
CXX := $(gccPrefix)$(CXX)
AS  := $(gccPrefix)$(AS)
AR  := $(gccPrefix)$(AR)
LD  := $(gccPrefix)$(LD)

.PHONY: all
all: dist

# BUILD ========================================================================
.PHONY: build
build: $(BUILD_DEPS) post-build

.PHONY: pre-build
pre-build: $(PRE_BUILD_DEPS)
    ifneq ($(PRE_BUILD), )
	    $(v)$(PRE_BUILD)
    endif

.PHONY: post-build
post-build: pre-build $(buildArtifact) $(POST_BUILD_DEPS)
    ifneq ($(postBuild), )
	    $(v)$(postBuild)
    endif
    ifneq ($(POST_BUILD), )
	    $(v)$(POST_BUILD)
    endif
# ==============================================================================

# CLEAN ========================================================================
.PHONY: clean
clean: post-clean

.PHONY: pre-clean
pre-clean:
    ifneq ($(PRE_CLEAN), )
	    $(v)$(PRE_CLEAN)
    endif

.PHONY: post-clean
post-clean: pre-clean
	$(v)rm -rf $(BUILD_BASE) $(DIST_BASE)
    ifneq ($(POST_CLEAN), )
	    $(v)$(POST_CLEAN)
    endif
# ==============================================================================

# BUILD ========================================================================
.PHONY: dist
dist: build post-dist

.PHONY: pre-dist
pre-dist:
    ifneq ($(PRE_DIST), )
	    $(v)$(PRE_DIST)
    endif

.PHONY: post-dist
post-dist: pre-dist
    ifneq ($(postDist), )
	    $(v)$(postDist)
    endif
    ifneq ($(POST_DIST), )
	    $(v)$(POST_DIST)
    endif
# ==============================================================================

$(buildArtifact): $(objFiles)
    ifeq ($(PROJ_TYPE), lib)
        ifeq ($(LIB_TYPE), shared)
	        @printf "$(nl)[LD] $(objFiles)\n"
	        $(v)$(LD) $(strip -o $@ $(objFiles) $(ldFlags) $(LDFLAGS))
        else
	        @printf "$(nl)[AR] $(objFiles)\n"
	        $(v)$(AR) $(strip $(arFlags) $@ $(objFiles))
        endif
    else
	    @printf "$(nl)[LD] $(objFiles)\n"
	    $(v)$(LD) $(strip -o $@ $(objFiles) $(ldFlags) $(LDFLAGS))
    endif

$(buildDir)/%.c$(objSuffix): %.c
	@mkdir -p $(dir $@)
	@printf "$(nl)[CC] $<\n"
	$(v)$(CC) $(strip $(cFlags) -MMD $(CFLAGS) $(includeFlags) -c $< -o $@)

$(buildDir)/%.cpp$(objSuffix): %.cpp
	@mkdir -p $(dir $@)
	@printf "$(nl)[CXX] $<\n"
	$(v)$(CXX) $(strip $(cxxFlags) -MMD -MP $(CXXFLAGS) $(includeFlags) -c $< -o $@)

$(buildDir)/%.S$(objSuffix): %.S
	@mkdir -p $(dir $@)
	@printf "$(nl)[AS] $<\n"
	$(v)$(AS) $(strip $(asFlags) -MMD $(ASFLAGS) $(includeFlags) -c $< -o $@)

-include $(deps)
