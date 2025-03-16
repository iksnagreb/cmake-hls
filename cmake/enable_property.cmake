# Utility function which enables a property option for some target taking
# optional arguments and values from variable PROPERTY to seed the property.
function(target_enable_property NAME PROPERTY)
    # Some logging of enabled target properties...
#    message(CHECK_START "Enable property ${PROPERTY} for target ${NAME}")
    # Initialize and empty local variable holding the property options
    set(OPTIONS "${ARGN}")
    # If this property has some global default, inherit these options
    if(DEFINED "${PROPERTY}")
        # Append to the empty property
        set(OPTIONS ${OPTIONS} ${${PROPERTY}})
    endif()
    # Add the property to the target properties
    set_target_properties(${NAME} PROPERTIES "${PROPERTY}" "${OPTIONS}")
    # Some logging of enabled target properties...
#    message(CHECK_PASS "done")
endfunction()
