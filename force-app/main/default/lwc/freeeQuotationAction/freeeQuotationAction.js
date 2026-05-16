import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import createQuotation from '@salesforce/apex/FreeeQuotationController.createQuotation';

export default class FreeeQuotationAction extends LightningElement {
    @api recordId;
    isLoading = false;

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;

        try {
            const message = await createQuotation({ quotationId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '成功',
                    message,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'エラー',
                    message: this.extractErrorMessage(error),
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
