// Contact Form Handler
document.addEventListener('DOMContentLoaded', function () {
    const contactForm = document.getElementById('contactForm');
    const successMessage = document.getElementById('successMessage');
    const errorMessage = document.getElementById('errorMessage');
    const submitBtn = contactForm.querySelector('.submit-btn');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoading = submitBtn.querySelector('.btn-loading');
    const messageTextarea = document.getElementById('message');
    const charCount = document.getElementById('charCount');

    // Character counter for message textarea
    if (messageTextarea && charCount) {
        messageTextarea.addEventListener('input', function () {
            const currentLength = this.value.length;
            charCount.textContent = currentLength;

            // Limit to 500 characters
            if (currentLength > 500) {
                this.value = this.value.substring(0, 500);
                charCount.textContent = '500';
            }
        });
    }

    // Form validation
    function validateForm() {
        const name = document.getElementById('name').value.trim();
        const email = document.getElementById('email').value.trim();
        const phone = document.getElementById('phone').value.trim();
        const subject = document.getElementById('subject').value;
        const message = document.getElementById('message').value.trim();
        const privacy = document.getElementById('privacy').checked;

        if (!name || !email || !phone || !subject || !message) {
            showError('Please fill in all required fields.');
            return false;
        }

        if (!privacy) {
            showError('Please agree to the Privacy Policy and Terms & Conditions.');
            return false;
        }

        // Email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            showError('Please enter a valid email address.');
            return false;
        }

        // Phone validation (basic)
        const phoneRegex = /^[0-9+\s-]{10,15}$/;
        if (!phoneRegex.test(phone)) {
            showError('Please enter a valid phone number.');
            return false;
        }

        return true;
    }

    // Show success message
    function showSuccess() {
        successMessage.style.display = 'flex';
        errorMessage.style.display = 'none';

        // Scroll to message
        successMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });

        // Hide after 5 seconds
        setTimeout(() => {
            successMessage.style.display = 'none';
        }, 5000);
    }

    // Show error message
    function showError(customMessage = null) {
        errorMessage.style.display = 'flex';
        successMessage.style.display = 'none';

        if (customMessage) {
            const errorText = errorMessage.querySelector('p');
            errorText.textContent = customMessage;
        }

        // Scroll to message
        errorMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });

        // Hide after 5 seconds
        setTimeout(() => {
            errorMessage.style.display = 'none';
        }, 5000);
    }

    // Hide messages
    function hideMessages() {
        successMessage.style.display = 'none';
        errorMessage.style.display = 'none';
    }

    // Form submission handler
    contactForm.addEventListener('submit', async function (e) {
        e.preventDefault();

        // Hide previous messages
        hideMessages();

        // Validate form
        if (!validateForm()) {
            return;
        }

        // Show loading state
        submitBtn.disabled = true;
        btnText.style.display = 'none';
        btnLoading.style.display = 'flex';

        // Get form data
        const formData = {
            name: document.getElementById('name').value.trim(),
            email: document.getElementById('email').value.trim(),
            phone: document.getElementById('phone').value.trim(),
            subject: document.getElementById('subject').value,
            message: document.getElementById('message').value.trim(),
            timestamp: new Date().toISOString()
        };

        try {
            // Simulate API call (replace with actual API endpoint)
            await simulateFormSubmission(formData);

            // Show success message
            showSuccess();

            // Reset form
            contactForm.reset();
            charCount.textContent = '0';

        } catch (error) {
            // Show error message
            showError();
            console.error('Form submission error:', error);
        } finally {
            // Reset button state
            submitBtn.disabled = false;
            btnText.style.display = 'inline';
            btnLoading.style.display = 'none';
        }
    });

    // Simulate form submission (replace with actual API call)
    function simulateFormSubmission(data) {
        return new Promise((resolve, reject) => {
            // Simulate network delay
            setTimeout(() => {
                // Log form data (in production, send to your backend)
                console.log('Form submitted:', data);

                // For demo purposes, always resolve successfully
                // In production, you would send data to your backend here
                // Example:
                // fetch('/api/contact', {
                //     method: 'POST',
                //     headers: { 'Content-Type': 'application/json' },
                //     body: JSON.stringify(data)
                // })
                // .then(response => response.json())
                // .then(result => resolve(result))
                // .catch(error => reject(error));

                resolve({ success: true });
            }, 1500);
        });
    }

    // Real-time validation feedback
    const inputs = contactForm.querySelectorAll('input, select, textarea');
    inputs.forEach(input => {
        input.addEventListener('blur', function () {
            if (this.hasAttribute('required') && !this.value.trim()) {
                this.style.borderColor = '#ef4444';
            } else {
                this.style.borderColor = '';
            }
        });

        input.addEventListener('focus', function () {
            this.style.borderColor = '';
        });
    });

    // Email validation on blur
    const emailInput = document.getElementById('email');
    if (emailInput) {
        emailInput.addEventListener('blur', function () {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (this.value && !emailRegex.test(this.value)) {
                this.style.borderColor = '#ef4444';
            }
        });
    }

    // Phone validation on blur
    const phoneInput = document.getElementById('phone');
    if (phoneInput) {
        phoneInput.addEventListener('blur', function () {
            const phoneRegex = /^[0-9+\s-]{10,15}$/;
            if (this.value && !phoneRegex.test(this.value)) {
                this.style.borderColor = '#ef4444';
            }
        });
    }
});