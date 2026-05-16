import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import createInvoice from '@salesforce/apex/FreeeInvoiceController.createInvoice';

export default class FreeeInvoiceAction extends LightningElement {
    @api recordId;
    isLoading = false;

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;

        try {
            const message = await createInvoice({ invoiceId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '成功',
                    message: message,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            const message = this.extractErrorMessage(error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'エラー',
                    message: message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'freee連携に失敗しました。';
    }
}