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

ifeq ($(PROJ_VERSION), )
    PROJ_VERSION := 0.1.0
endif

ifeq ($(shell sh -c "echo $(PROJ_VERSION) | grep -oP '[0-9]+\.[0-9]+\.[0-9]+.*'"), )
    $(error Invalid PROJECT_VERSION: $(PROJECT_VERSION))
endif
projVersionMajor := $(shell echo $(PROJ_VERSION) | cut -d'.' -f1)
projVersionMinor := $(shell echo $(PROJ_VERSION) | cut -d'.' -f2)
projVersionPatch := $(shell echo $(PROJ_VERSION) | cut -d'.' -f3-)

ifeq ($(PROJ_TYPE), )
    PROJ_TYPE := app
endif
ifneq ($(PROJ_TYPE), app)
    ifneq ($(PROJ_TYPE), lib)
        $(error Unsupported PROJ_TYPE: $(PROJ_TYPE))
    else
        ifeq ($(LIB_TYPE), )
            LIB_TYPE := shared
        endif
        ifneq ($(LIB_TYPE), shared)
            ifneq ($(LIB_TYPE), static)
                $(error Unsupported LIB_TYPE: $(LIB_TYPE))
            endif
        endif
    endif
endif

ifeq ($(DEBUG), )
    DEBUG := 0
endif
ifneq ($(DEBUG), 0)
    ifneq ($(DEBUG), 1)
        $(error Invalid value for DEBUG: $(DEBUG))
    endif
endif

ifeq ($(V), )
    V := 0
endif
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

ifeq ($(BUILD_BASE), )
    BUILD_BASE := build
endif
ifeq ($(BUILD_DIR), )
    ifneq ($(HOST), )
        fullBuildDir := $(BUILD_BASE)/$(HOST)
    else
        fullBuildDir := $(BUILD_BASE)
    endif
else
    fullBuildDir := $(BUILD_BASE)/$(BUILD_DIR)
endif

ifeq ($(DIST_BASE), )
    DIST_BASE := dist
endif
ifeq ($(DIST_DIR), )
    ifneq ($(HOST), )
        fullDistDir := $(DIST_BASE)/$(HOST)
    else
        fullDistDir := $(DIST_BASE)
    endif
else
    fullDistDir := $(DIST_BASE)/$(DIST_DIR)
endif

ifneq ($(wildcard src), )
    srcDirs += src
endif
srcDirs += $(SRC_DIRS)

ifneq ($(wildcard include), )
    includeDirs += include
    ifeq ($(PROJ_TYPE, lib)
        postDist += mkdir -p $(fullDistDir); cp -a -R include $(fullDistDir);
    endif
endif
includeDirs += $(INCLUDE_DIRS)

ifeq ($(DEBUG), 1)
    objSuffix := .dbg.o
else
    objSuffix := .o
endif
srcFiles := $(strip $(foreach srcDir, $(srcDirs), $(shell find $(srcDir) -type f -name *.c -or -name *.cpp -or -name *.S 2> /dev/null)))
objFiles := $(srcFiles:%=$(fullBuildDir)/%$(objSuffix))
deps := $(objFiles:.o=.d)

ifeq ($(DEBUG), 1)
    artifactNameSuffix := _d
endif

ifeq ($(PROJ_TYPE), app)
    artifactName := $(PROJ_NAME)$(artifactNameSuffix)
    postDist     += mkdir -p $(fullDistDir)/bin; cp -a $(fullBuildDir)/$(artifactName) $(fullDistDir)/bin;
else
    postDist         += mkdir -p $(fullDistDir)/lib;
    artifactBaseName := lib$(PROJ_NAME)$(projVersionMajor)$(artifactNameSuffix)
    ifeq ($(LIB_TYPE), static)
        postDist         += cp -a $(fullBuildDir)/*.a* $(fullDistDir)/lib;
        artifactBaseName := $(artifactBaseName).a
    else
        postDist         += cp -a $(fullBuildDir)/*.so* $(fullDistDir)/lib;
        artifactBaseName := $(artifactBaseName).so
    endif
    artifactName := $(artifactBaseName).$(projVersionMajor).$(projVersionMinor).$(projVersionPatch)
    postBuild    := cd $(fullBuildDir); ln -sf $(artifactName) $(artifactBaseName);
endif
buildArtifact := $(fullBuildDir)/$(artifactName)

cFlags += -Wall
cxxFlags += -Wall
ifeq ($(DEBUG), 1)
    cFlags   += -g3
    cxxFlags += -g3
    asFlags  += -g3
endif

includeFlags += $(strip $(foreach srcDir, $(srcDirs), -I$(srcDir)))
includeFlags += $(strip $(foreach includeDir, $(includeDirs), -I$(includeDir)))

ifeq ($(PROJ_TYPE), lib)
    ifeq ($(LIB_TYPE), shared)
        cFlags   += -fPIC
        cxxFlags += -fPIC
        ldFlags  += -shared
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

$(fullBuildDir)/%.c$(objSuffix): %.c
	@mkdir -p $(dir $@)
	@printf "$(nl)[CC] $<\n"
	$(v)$(CC) $(strip $(cFlags) -MMD $(CFLAGS) $(includeFlags) -c $< -o $@)

$(fullBuildDir)/%.cpp$(objSuffix): %.cpp
	@mkdir -p $(dir $@)
	@printf "$(nl)[CXX] $<\n"
	$(v)$(CXX) $(strip $(cxxFlags) -MMD -MP $(CXXFLAGS) $(includeFlags) -c $< -o $@)

$(fullBuildDir)/%.S$(objSuffix): %.S
	@mkdir -p $(dir $@)
	@printf "$(nl)[AS] $<\n"
	$(v)$(AS) $(strip $(asFlags) -MMD $(ASFLAGS) $(includeFlags) -c $< -o $@)

-include $(deps)
