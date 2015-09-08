find_package(PythonInterp QUIET)
if (NOT PYTHONINTERP_FOUND)
    message(WARNING "No Python interpreter found. Unable to generate C bindings for Iron.")
else()
    set(BINDINGS_DIR ${CMAKE_CURRENT_BINARY_DIR}/bindings)
    file(MAKE_DIRECTORY ${BINDINGS_DIR})
    set(OPENCMISS_H ${BINDINGS_DIR}/opencmiss.h)
    
    # C-Bindings extra target
    set(HAVE_C_BINDINGS FALSE)
    if (WITH_C_BINDINGS)
        message(STATUS "Configuring to create C bindings")
        set(OPENCMISS_C_F90 ${BINDINGS_DIR}/opencmiss_c.f90)
        #set_source_files_properties(${OPENCMISS_C_F90} PROPERTIES GENERATED TRUE)
        add_custom_command(OUTPUT ${OPENCMISS_C_F90} ${OPENCMISS_H}
            COMMAND ${PYTHON_EXECUTABLE} generate_bindings ${CMAKE_CURRENT_SOURCE_DIR} C ${OPENCMISS_H} ${OPENCMISS_C_F90}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bindings)
        set(HAVE_C_BINDINGS TRUE)
    endif()
    
    # Python-Bindings extra target
    set(HAVE_Python_BINDINGS FALSE)
    if (WITH_Python_BINDINGS)
        message(STATUS "Configuring to create Python bindings")
        find_package(PythonLibs QUIET)
        find_package(SWIG QUIET)
        if (SWIG_FOUND AND PYTHONLIBS_FOUND AND HAVE_C_BINDINGS)
            # The name of this module name is very important and is used 
            # in a number of places be careful if you change it.
            set(IRON_MODULE_NAME iron)

            # Copy interface files
            set(SWIG_INTERFACE_SRCS)
            set(INTERFACE_FILES numpy.i numpy_extra.i opencmiss_py.i)
            foreach(_i_f ${INTERFACE_FILES})
                file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/bindings/python/${_i_f} DESTINATION ${BINDINGS_DIR})
                list(APPEND SWIG_INTERFACE_SRCS ${BINDINGS_DIR}/${_i_f})
            endforeach()
            
            #Generate interface
            set(SWIG_IFACE ${BINDINGS_DIR}/opencmiss.i)
            add_custom_command(OUTPUT ${SWIG_IFACE}
                COMMAND ${PYTHON_EXECUTABLE} generate_bindings ${CMAKE_CURRENT_SOURCE_DIR} SWIG ${SWIG_IFACE}
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bindings)
            
            set(SWIG_OUTDIR "${CMAKE_CURRENT_BINARY_DIR}/opencmiss/iron")
            #Generate module
            set(IRON_PY ${SWIG_OUTDIR}/iron.py)
            add_custom_command(OUTPUT ${IRON_PY}
                COMMAND ${PYTHON_EXECUTABLE} generate_bindings ${CMAKE_CURRENT_SOURCE_DIR} Python ${IRON_MODULE_NAME} ${SWIG_OUTDIR}
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bindings)
            
            # Generate C wrapper
            set(PYTHON_WRAPPER ${BINDINGS_DIR}/python_wrapper.c)
            add_custom_command(OUTPUT ${PYTHON_WRAPPER}
                DEPENDS ${SWIG_IFACE}
                DEPENDS ${SWIG_INTERFACE_SRCS}
                DEPENDS ${IRON_PY}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${SWIG_OUTDIR}
                COMMAND ${SWIG_EXECUTABLE} -python -o ${PYTHON_WRAPPER}
                    -module ${IRON_MODULE_NAME} -outdir ${SWIG_OUTDIR} opencmiss_py.i
                WORKING_DIRECTORY ${BINDINGS_DIR})
            
            # Configure _utils.py
            set(UTILS_PY ${SWIG_OUTDIR}/_utils.py)
            configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/python/opencmiss/iron/_utils.py
                ${UTILS_PY} @ONLY)

            # Copy over python package files, file copy doesn't work resort to using configure_file
            set(PKGUTIL_INIT_PY ${CMAKE_CURRENT_BINARY_DIR}/opencmiss/__init__.py)
            configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/python/opencmiss/__init__.py
                ${PKGUTIL_INIT_PY})
            set(INIT_PY "${SWIG_OUTDIR}/__init__.py")
            configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/python/opencmiss/iron/__init__.py
                ${INIT_PY})
 
            # Copy over setup.py
            set(SETUP_PY ${CMAKE_CURRENT_BINARY_DIR}/setup.py)
            configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/python/setup.py ${SETUP_PY})

            #Generate wrapper object
            execute_process(COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/utils/numpy_include.py
                OUTPUT_VARIABLE NUMPY_INCLUDES
                RESULT_VARIABLE RES_NUMPY_INC
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            if (NOT RES_NUMPY_INC)
                # The name of this target is very important
                set(IRON_MODULE_TARGET_NAME _${IRON_MODULE_NAME}) 
                add_library(${IRON_MODULE_TARGET_NAME} MODULE ${PYTHON_WRAPPER} ${OPENCMISS_C_F90} ${OPENCMISS_H})
                target_link_libraries(${IRON_MODULE_TARGET_NAME} PUBLIC iron ${PYTHON_LIBRARIES})
                target_include_directories(${IRON_MODULE_TARGET_NAME} PRIVATE ${BINDINGS_DIR} ${PYTHON_INCLUDE_DIRS} ${NUMPY_INCLUDES})
                set_target_properties(${IRON_MODULE_TARGET_NAME} PROPERTIES PREFIX ""
                    LIBRARY_OUTPUT_DIRECTORY ${SWIG_OUTDIR}
                    iRUNTIME_OUTPUT_DIRECTORY ${SWIG_OUTDIR})
                if(WIN32 AND NOT CYGWIN)
                    set_target_properties(${IRON_MODULE_TARGET_NAME} PROPERTIES SUFFIX ".pyd")
                endif()
                #install(TARGETS _iron
                #    EXPORT iron-config
                #    DESTINATION lib
                #    INCLUDES DESTINATION include/iron)
            else()
                message(FATAL_ERROR "Unable to generate numpy includes module.")
            endif()
            set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES
                "${SWIG_IFACE};${IRON_PY};${PYTHON_WRAPPER};${OPENCMISS_C_F90};${OPENCMISS_H};${SWIG_INTERFACE_SRCS};${SWIG_OUTDIR}/iron.py;${INIT_PY};${PKGUTIL_INIT_PY};${SETUP_PY};${UTILS_PY};${SWIG_OUTDIR};${BINDINGS_DIR};${CMAKE_CURRENT_BINARY_DIR}/opencmiss")
            set(HAVE_Python_BINDINGS TRUE)
        else()
            message(WARNING "No SWIG or Python libraries found or no C bindings built. Unable to generate Python bindings for Iron.")            
        endif()
    endif()   
endif()
